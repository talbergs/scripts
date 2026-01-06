#!/usr/bin/env node
/**
 * JIRA Comments Update
 *
 * Maintains a tracking comment on JIRA tickets for subissues matching specified criteria.
 * Appends to an existing tracking comment or creates one if it doesn't exist.
 *
 * Usage:
 *   node jira-comments-update.js [options]
 *
 * Environment variables required:
 *   JIRA_BASE_URL  - Your JIRA instance URL
 *   JIRA_EMAIL     - Your JIRA account email
 *   JIRA_API_TOKEN - Your JIRA API token
 *
 * Options:
 *   --input, -i       Input JSON file from jira-comments-analyse.js (default: ./jira-subissues.json)
 *   --dry-run, -n     Show what would be updated without making changes
 *   --marker, -m      Tracking comment marker (default: [SUBISSUE-TRACKER])
 *   --help, -h        Show this help message
 */

const https = require('https');
const fs = require('fs');

const TRACKING_MARKER = '[SUBISSUE-TRACKER]';

function parseArgs(args) {
  const options = {
    inputFile: './jira-subissues.json',
    dryRun: false,
    marker: TRACKING_MARKER,
    help: false
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--input' || arg === '-i') {
      options.inputFile = args[++i];
    } else if (arg === '--dry-run' || arg === '-n') {
      options.dryRun = true;
    } else if (arg === '--marker' || arg === '-m') {
      options.marker = args[++i];
    }
  }

  return options;
}

function showHelp() {
  const helpText = `
JIRA Comments Update - Maintain tracking comments for matched subissues

Usage:
  node jira-comments-update.js [options]

Options:
  --input, -i <file>    Input JSON from jira-comments-analyse.js (default: ./jira-subissues.json)
  --dry-run, -n         Preview changes without updating JIRA
  --marker, -m <text>   Tracking comment marker (default: ${TRACKING_MARKER})
  --help, -h            Show this help message

Environment Variables (required):
  JIRA_BASE_URL   Your JIRA instance URL
  JIRA_EMAIL      Your JIRA account email
  JIRA_API_TOKEN  Your JIRA API token

Behavior:
  1. Reads subissues from the analysis file
  2. Filters subissues matching criteria (currently: contains "~mtalbergs")
  3. For each ticket with matches, finds or creates a tracking comment
  4. Appends new entries to the tracking comment with timestamp

Tracking Comment Format:
  ${TRACKING_MARKER}
  --- Update 2026-01-05T12:00:00Z ---
  (#1) OPEN - Subissue title
  (#2) RESOLVED - Another subissue
`;
  console.log(helpText);
}

function validateEnv() {
  const required = ['JIRA_BASE_URL', 'JIRA_EMAIL', 'JIRA_API_TOKEN'];
  const missing = required.filter(key => !process.env[key]);

  if (missing.length > 0) {
    console.error('Error: Missing required environment variables:');
    missing.forEach(key => console.error(`  - ${key}`));
    process.exit(1);
  }
}

function loadInputFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: Input file not found: ${filePath}`);
    console.error('Run jira-comments-analyse.js first to generate the input file.');
    process.exit(1);
  }

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(content);
  } catch (err) {
    console.error(`Error: Could not parse input file: ${err.message}`);
    process.exit(1);
  }
}

/**
 * Criteria check - determines if a subissue should be tracked
 * Currently: checks if comment contains "~mtalbergs"
 *
 * @param {object} subissue - The subissue object
 * @returns {boolean} - True if subissue matches criteria
 */
function matchesCriteria(subissue) {
  // Dummy check: contains "~mtalbergs"
  const text = subissue.full_text || '';
  return text.includes('~mtalbergs');
}

function makeRequest(method, url, auth, body = null) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: 443,
      path: urlObj.pathname + urlObj.search,
      method,
      headers: {
        'Authorization': `Basic ${auth}`,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(data ? JSON.parse(data) : {});
          } catch (e) {
            resolve({});
          }
        } else if (res.statusCode === 404) {
          resolve(null);
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function getTicketComments(ticketKey, baseUrl, auth) {
  const url = `${baseUrl}/rest/api/3/issue/${ticketKey}/comment`;
  const result = await makeRequest('GET', url, auth);
  return result?.comments || [];
}

function extractTextFromADF(adf) {
  if (!adf) return '';
  if (typeof adf === 'string') return adf;

  function extractFromNode(node) {
    if (!node) return '';
    if (node.type === 'text') return node.text || '';
    if (node.content && Array.isArray(node.content)) {
      return node.content.map(extractFromNode).join('');
    }
    return '';
  }

  return extractFromNode(adf).trim();
}

function textToADF(text) {
  // Convert plain text to Atlassian Document Format
  const lines = text.split('\n');
  const content = lines.map(line => ({
    type: 'paragraph',
    content: line ? [{ type: 'text', text: line }] : []
  }));

  return {
    type: 'doc',
    version: 1,
    content
  };
}

async function findTrackingComment(ticketKey, marker, baseUrl, auth) {
  const comments = await getTicketComments(ticketKey, baseUrl, auth);

  for (const comment of comments) {
    const body = extractTextFromADF(comment.body);
    if (body.includes(marker)) {
      return {
        id: comment.id,
        body
      };
    }
  }

  return null;
}

function buildUpdateEntry(subissues, timestamp) {
  const lines = [`--- Update ${timestamp} ---`];

  for (const s of subissues) {
    lines.push(`(#${s.subissue_number}) ${s.state} - ${s.title}`);
  }

  return lines.join('\n');
}

async function createComment(ticketKey, content, baseUrl, auth) {
  const url = `${baseUrl}/rest/api/3/issue/${ticketKey}/comment`;
  const body = { body: textToADF(content) };
  return makeRequest('POST', url, auth, body);
}

async function updateComment(ticketKey, commentId, content, baseUrl, auth) {
  const url = `${baseUrl}/rest/api/3/issue/${ticketKey}/comment/${commentId}`;
  const body = { body: textToADF(content) };
  return makeRequest('PUT', url, auth, body);
}

async function processUpdates(options) {
  validateEnv();

  const baseUrl = process.env.JIRA_BASE_URL.replace(/\/$/, '');
  const auth = Buffer.from(`${process.env.JIRA_EMAIL}:${process.env.JIRA_API_TOKEN}`).toString('base64');

  const data = loadInputFile(options.inputFile);
  const subissues = data.subissues || [];

  console.log(`Loaded ${subissues.length} subissue(s) from analysis`);

  // Filter by criteria
  const matched = subissues.filter(matchesCriteria);
  console.log(`${matched.length} subissue(s) match criteria (contains "~mtalbergs")`);

  if (matched.length === 0) {
    console.log('No matching subissues to track.');
    return;
  }

  // Group matched subissues by ticket
  const byTicket = {};
  for (const s of matched) {
    if (!byTicket[s.ticket]) {
      byTicket[s.ticket] = [];
    }
    byTicket[s.ticket].push(s);
  }

  const timestamp = new Date().toISOString();
  const ticketKeys = Object.keys(byTicket);

  console.log(`\nProcessing ${ticketKeys.length} ticket(s)...`);

  if (options.dryRun) {
    console.log('(DRY RUN - no changes will be made)\n');
  }

  for (const ticketKey of ticketKeys) {
    const ticketSubissues = byTicket[ticketKey];
    process.stdout.write(`  ${ticketKey} (${ticketSubissues.length} match)... `);

    try {
      // Find existing tracking comment
      const existing = await findTrackingComment(ticketKey, options.marker, baseUrl, auth);
      const updateEntry = buildUpdateEntry(ticketSubissues, timestamp);

      if (existing) {
        // Append to existing comment
        const newContent = existing.body + '\n\n' + updateEntry;

        if (options.dryRun) {
          console.log('WOULD UPDATE existing tracking comment');
        } else {
          await updateComment(ticketKey, existing.id, newContent, baseUrl, auth);
          console.log('UPDATED tracking comment');
        }
      } else {
        // Create new tracking comment
        const newContent = `${options.marker}\nAutomated subissue tracking\n\n${updateEntry}`;

        if (options.dryRun) {
          console.log('WOULD CREATE new tracking comment');
        } else {
          await createComment(ticketKey, newContent, baseUrl, auth);
          console.log('CREATED tracking comment');
        }
      }
    } catch (err) {
      console.log(`ERROR: ${err.message}`);
    }
  }

  console.log('\nDone.');

  // Show summary of what was tracked
  console.log('\nTracked subissues:');
  for (const s of matched) {
    const stateIcon = s.state === 'OPEN' ? '○' : s.state === 'RESOLVED' ? '✓' : '✗';
    console.log(`  ${stateIcon} ${s.ticket}#${s.subissue_number} [${s.state}] ${s.title}`);
  }
}

// Main
const options = parseArgs(process.argv.slice(2));

if (options.help) {
  showHelp();
  process.exit(0);
}

processUpdates(options).catch(err => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
