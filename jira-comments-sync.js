#!/usr/bin/env node
/**
 * JIRA Comments Sync
 *
 * Collects comments from authorized JIRA tickets and maintains them in a structured JSON file.
 *
 * Usage:
 *   node jira-comments-sync.js [options]
 *
 * Environment variables required:
 *   JIRA_BASE_URL  - Your JIRA instance URL (e.g., https://company.atlassian.net)
 *   JIRA_EMAIL     - Your JIRA account email
 *   JIRA_API_TOKEN - Your JIRA API token (generate at https://id.atlassian.com/manage-profile/security/api-tokens)
 *
 * Options:
 *   --tickets-file, -t  Path to file containing ticket IDs (default: ./tickets.txt)
 *   --output, -o        Output JSON file path (default: ./jira-comments.json)
 *   --help, -h          Show this help message
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// Output file format documentation (included in output file header)
const FORMAT_DOCUMENTATION = {
  _format_version: "1.0",
  _format_description: "JIRA Comments Collection",
  _format_schema: {
    metadata: {
      description: "Sync metadata",
      fields: {
        last_sync: "ISO 8601 timestamp of last sync",
        tickets_file: "Path to tickets input file",
        jira_base_url: "JIRA instance URL used",
        total_tickets: "Number of tickets processed",
        total_comments: "Total comments collected"
      }
    },
    tickets: {
      description: "Object keyed by ticket ID",
      fields: {
        key: "JIRA ticket key (e.g., PROJ-123)",
        summary: "Ticket summary/title",
        status: "Current ticket status",
        url: "Direct link to ticket",
        comments: {
          description: "Array of comment objects",
          fields: {
            id: "Unique comment ID",
            author: "Display name of comment author",
            author_email: "Email of comment author",
            created: "ISO 8601 timestamp when comment was created",
            updated: "ISO 8601 timestamp when comment was last updated",
            body: "Comment text content"
          }
        },
        last_fetched: "ISO 8601 timestamp when this ticket was last fetched"
      }
    }
  }
};

function parseArgs(args) {
  const options = {
    ticketsFile: './tickets.txt',
    outputFile: './jira-comments.json',
    help: false
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--tickets-file' || arg === '-t') {
      options.ticketsFile = args[++i];
    } else if (arg === '--output' || arg === '-o') {
      options.outputFile = args[++i];
    }
  }

  return options;
}

function showHelp() {
  const helpText = `
JIRA Comments Sync - Collect and maintain JIRA ticket comments

Usage:
  node jira-comments-sync.js [options]

Options:
  --tickets-file, -t <file>  Path to file with ticket IDs, one per line (default: ./tickets.txt)
  --output, -o <file>        Output JSON file path (default: ./jira-comments.json)
  --help, -h                 Show this help message

Environment Variables (required):
  JIRA_BASE_URL   Your JIRA instance URL (e.g., https://company.atlassian.net)
  JIRA_EMAIL      Your JIRA account email
  JIRA_API_TOKEN  Your JIRA API token

Tickets File Format:
  One ticket ID per line. Empty lines and lines starting with # are ignored.
  Example:
    PROJ-123
    PROJ-456
    # This is a comment
    PROJ-789

Output:
  JSON file with format documentation in _format_* fields at the top.
`;
  console.log(helpText);
}

function validateEnv() {
  const required = ['JIRA_BASE_URL', 'JIRA_EMAIL', 'JIRA_API_TOKEN'];
  const missing = required.filter(key => !process.env[key]);

  if (missing.length > 0) {
    console.error('Error: Missing required environment variables:');
    missing.forEach(key => console.error(`  - ${key}`));
    console.error('\nSet these variables or use --help for more info.');
    process.exit(1);
  }
}

function readTicketsFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: Tickets file not found: ${filePath}`);
    process.exit(1);
  }

  const content = fs.readFileSync(filePath, 'utf8');
  return content
    .split('\n')
    .map(line => line.trim())
    .filter(line => line && !line.startsWith('#'));
}

function loadExistingData(outputFile) {
  if (fs.existsSync(outputFile)) {
    try {
      const content = fs.readFileSync(outputFile, 'utf8');
      return JSON.parse(content);
    } catch (err) {
      console.warn(`Warning: Could not parse existing output file, starting fresh.`);
    }
  }
  return null;
}

function makeRequest(url, auth) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: 443,
      path: urlObj.pathname + urlObj.search,
      method: 'GET',
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
        if (res.statusCode === 200) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error(`Failed to parse response: ${e.message}`));
          }
        } else if (res.statusCode === 404) {
          resolve(null);
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function fetchTicketWithComments(ticketKey, baseUrl, auth) {
  const ticketUrl = `${baseUrl}/rest/api/3/issue/${ticketKey}?fields=summary,status`;
  const commentsUrl = `${baseUrl}/rest/api/3/issue/${ticketKey}/comment`;

  try {
    const [ticketData, commentsData] = await Promise.all([
      makeRequest(ticketUrl, auth),
      makeRequest(commentsUrl, auth)
    ]);

    if (!ticketData) {
      return { error: 'Ticket not found or not accessible' };
    }

    const comments = (commentsData?.comments || []).map(comment => ({
      id: comment.id,
      author: comment.author?.displayName || 'Unknown',
      author_email: comment.author?.emailAddress || null,
      created: comment.created,
      updated: comment.updated,
      body: extractTextFromADF(comment.body)
    }));

    return {
      key: ticketData.key,
      summary: ticketData.fields?.summary || '',
      status: ticketData.fields?.status?.name || 'Unknown',
      url: `${baseUrl}/browse/${ticketData.key}`,
      comments,
      last_fetched: new Date().toISOString()
    };
  } catch (err) {
    return { error: err.message };
  }
}

// Extract plain text from Atlassian Document Format (ADF)
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

  const text = extractFromNode(adf);
  return text.trim();
}

async function syncComments(options) {
  validateEnv();

  const baseUrl = process.env.JIRA_BASE_URL.replace(/\/$/, '');
  const auth = Buffer.from(`${process.env.JIRA_EMAIL}:${process.env.JIRA_API_TOKEN}`).toString('base64');

  const ticketKeys = readTicketsFile(options.ticketsFile);

  if (ticketKeys.length === 0) {
    console.error('Error: No ticket IDs found in tickets file.');
    process.exit(1);
  }

  console.log(`Syncing ${ticketKeys.length} ticket(s) from JIRA...`);

  const existingData = loadExistingData(options.outputFile);
  const tickets = existingData?.tickets || {};

  let successCount = 0;
  let errorCount = 0;
  let totalComments = 0;

  for (const ticketKey of ticketKeys) {
    process.stdout.write(`  ${ticketKey}... `);

    const result = await fetchTicketWithComments(ticketKey, baseUrl, auth);

    if (result.error) {
      console.log(`ERROR: ${result.error}`);
      errorCount++;
      // Keep existing data if we have it
      if (tickets[ticketKey]) {
        tickets[ticketKey].sync_error = result.error;
      }
    } else {
      console.log(`OK (${result.comments.length} comments)`);
      tickets[ticketKey] = result;
      successCount++;
      totalComments += result.comments.length;
    }
  }

  const output = {
    ...FORMAT_DOCUMENTATION,
    metadata: {
      last_sync: new Date().toISOString(),
      tickets_file: path.resolve(options.ticketsFile),
      jira_base_url: baseUrl,
      total_tickets: successCount,
      total_comments: totalComments
    },
    tickets
  };

  fs.writeFileSync(options.outputFile, JSON.stringify(output, null, 2));

  console.log(`\nSync complete:`);
  console.log(`  ✓ ${successCount} ticket(s) synced`);
  if (errorCount > 0) {
    console.log(`  ✗ ${errorCount} error(s)`);
  }
  console.log(`  ${totalComments} total comments`);
  console.log(`  Output: ${options.outputFile}`);
}

// Main
const options = parseArgs(process.argv.slice(2));

if (options.help) {
  showHelp();
  process.exit(0);
}

syncComments(options).catch(err => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
