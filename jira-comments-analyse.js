#!/usr/bin/env node
/**
 * JIRA Comments Analyser
 *
 * Parses the output from jira-comments-sync.js and extracts subissues from comments.
 * Subissues are identified by "(N)" notation at the start of a comment, where N is a number.
 * State is determined by the last occurrence of OPEN, CLOSED, or RESOLVED in the comment text.
 *
 * Usage:
 *   node jira-comments-analyse.js [options]
 *
 * Options:
 *   --input, -i      Input JSON file from jira-comments-sync.js (default: ./jira-comments.json)
 *   --output, -o     Output JSON file path (default: ./jira-subissues.json)
 *   --filter, -f     Filter by state: OPEN, CLOSED, RESOLVED, or ALL (default: ALL)
 *   --help, -h       Show this help message
 */

const fs = require('fs');
const path = require('path');

// Output file format documentation
const FORMAT_DOCUMENTATION = {
  _format_version: "1.0",
  _format_description: "JIRA Subissues Analysis",
  _format_schema: {
    metadata: {
      description: "Analysis metadata",
      fields: {
        analysed_at: "ISO 8601 timestamp of analysis",
        source_file: "Path to input jira-comments.json",
        source_sync_time: "When the source file was last synced",
        total_subissues: "Total number of subissues found",
        by_state: "Count of subissues grouped by state"
      }
    },
    subissues: {
      description: "Array of extracted subissues",
      fields: {
        ticket: "Parent JIRA ticket key",
        ticket_url: "URL to parent ticket",
        subissue_number: "The numeric identifier from (N) notation",
        state: "OPEN, CLOSED, or RESOLVED (based on last keyword found)",
        title: "First line or summary of the subissue comment",
        full_text: "Complete comment text",
        comment_id: "Original comment ID",
        author: "Comment author",
        created: "When the comment was created",
        updated: "When the comment was last updated"
      }
    },
    by_ticket: {
      description: "Subissues grouped by parent ticket",
      structure: "Object keyed by ticket ID, each containing array of subissues"
    }
  }
};

function parseArgs(args) {
  const options = {
    inputFile: './jira-comments.json',
    outputFile: './jira-subissues.json',
    filter: 'ALL',
    help: false
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--input' || arg === '-i') {
      options.inputFile = args[++i];
    } else if (arg === '--output' || arg === '-o') {
      options.outputFile = args[++i];
    } else if (arg === '--filter' || arg === '-f') {
      options.filter = (args[++i] || '').toUpperCase();
    }
  }

  return options;
}

function showHelp() {
  const helpText = `
JIRA Comments Analyser - Extract subissues from JIRA comments

Usage:
  node jira-comments-analyse.js [options]

Options:
  --input, -i <file>   Input JSON file from jira-comments-sync.js (default: ./jira-comments.json)
  --output, -o <file>  Output JSON file path (default: ./jira-subissues.json)
  --filter, -f <state> Filter results by state: OPEN, CLOSED, RESOLVED, or ALL (default: ALL)
  --help, -h           Show this help message

Subissue Detection:
  Comments starting with "(N)" where N is a number are treated as subissues.
  Examples:
    "(1) Implement login feature"      -> Subissue #1
    "(42) Fix the bug in parser"       -> Subissue #42
    "(3) RESOLVED - completed task"    -> Subissue #3, state: RESOLVED

State Detection:
  The state is determined by the LAST occurrence of these keywords (case-insensitive):
    - OPEN     : Subissue is open/pending
    - CLOSED   : Subissue has been closed
    - RESOLVED : Subissue has been resolved

  If no keyword is found, state defaults to OPEN.

Output:
  JSON file with subissues list and grouping by parent ticket.
`;
  console.log(helpText);
}

function loadInputFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: Input file not found: ${filePath}`);
    console.error('Run jira-comments-sync.js first to generate the input file.');
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

function detectState(text) {
  const normalizedText = text.toUpperCase();

  // Find last occurrence of each keyword
  const states = [
    { state: 'OPEN', index: normalizedText.lastIndexOf('OPEN') },
    { state: 'CLOSED', index: normalizedText.lastIndexOf('CLOSED') },
    { state: 'RESOLVED', index: normalizedText.lastIndexOf('RESOLVED') }
  ].filter(s => s.index !== -1);

  if (states.length === 0) {
    return 'OPEN'; // Default state
  }

  // Return the state with the highest (last) index
  states.sort((a, b) => b.index - a.index);
  return states[0].state;
}

function extractTitle(text) {
  // Get first line or first 100 chars as title
  const firstLine = text.split('\n')[0].trim();
  // Remove the (N) prefix for cleaner title
  const withoutPrefix = firstLine.replace(/^\(\d+\)\s*/, '');

  if (withoutPrefix.length > 100) {
    return withoutPrefix.substring(0, 97) + '...';
  }
  return withoutPrefix;
}

function extractSubissues(data) {
  const subissues = [];
  const subissuePattern = /^\((\d+)\)/;

  const tickets = data.tickets || {};

  for (const [ticketKey, ticket] of Object.entries(tickets)) {
    if (!ticket.comments || ticket.error) continue;

    for (const comment of ticket.comments) {
      const body = comment.body || '';
      const match = body.match(subissuePattern);

      if (match) {
        const subissueNumber = parseInt(match[1], 10);
        const state = detectState(body);

        subissues.push({
          ticket: ticketKey,
          ticket_url: ticket.url,
          subissue_number: subissueNumber,
          state,
          title: extractTitle(body),
          full_text: body,
          comment_id: comment.id,
          author: comment.author,
          author_email: comment.author_email,
          created: comment.created,
          updated: comment.updated
        });
      }
    }
  }

  // Sort by ticket, then by subissue number
  subissues.sort((a, b) => {
    if (a.ticket !== b.ticket) {
      return a.ticket.localeCompare(b.ticket);
    }
    return a.subissue_number - b.subissue_number;
  });

  return subissues;
}

function groupByTicket(subissues) {
  const grouped = {};

  for (const subissue of subissues) {
    if (!grouped[subissue.ticket]) {
      grouped[subissue.ticket] = {
        ticket_url: subissue.ticket_url,
        subissues: []
      };
    }
    grouped[subissue.ticket].subissues.push(subissue);
  }

  return grouped;
}

function countByState(subissues) {
  const counts = { OPEN: 0, CLOSED: 0, RESOLVED: 0 };
  for (const s of subissues) {
    counts[s.state] = (counts[s.state] || 0) + 1;
  }
  return counts;
}

function analyseComments(options) {
  const data = loadInputFile(options.inputFile);

  console.log(`Analysing comments from: ${options.inputFile}`);

  let subissues = extractSubissues(data);

  console.log(`Found ${subissues.length} subissue(s)`);

  // Apply filter if specified
  if (options.filter !== 'ALL') {
    const validStates = ['OPEN', 'CLOSED', 'RESOLVED'];
    if (!validStates.includes(options.filter)) {
      console.error(`Error: Invalid filter state "${options.filter}". Use: ${validStates.join(', ')}, or ALL`);
      process.exit(1);
    }

    const beforeCount = subissues.length;
    subissues = subissues.filter(s => s.state === options.filter);
    console.log(`Filtered to ${subissues.length} ${options.filter} subissue(s)`);
  }

  const byState = countByState(subissues);
  const byTicket = groupByTicket(subissues);

  const output = {
    ...FORMAT_DOCUMENTATION,
    metadata: {
      analysed_at: new Date().toISOString(),
      source_file: path.resolve(options.inputFile),
      source_sync_time: data.metadata?.last_sync || null,
      total_subissues: subissues.length,
      filter_applied: options.filter !== 'ALL' ? options.filter : null,
      by_state: byState
    },
    subissues,
    by_ticket: byTicket
  };

  fs.writeFileSync(options.outputFile, JSON.stringify(output, null, 2));

  // Print summary
  console.log(`\nAnalysis complete:`);
  console.log(`  OPEN:     ${byState.OPEN}`);
  console.log(`  CLOSED:   ${byState.CLOSED}`);
  console.log(`  RESOLVED: ${byState.RESOLVED}`);
  console.log(`  ─────────────`);
  console.log(`  Total:    ${subissues.length}`);
  console.log(`\nOutput: ${options.outputFile}`);

  // List subissues if not too many
  if (subissues.length > 0 && subissues.length <= 20) {
    console.log(`\nSubissues:`);
    for (const s of subissues) {
      const stateIcon = s.state === 'OPEN' ? '○' : s.state === 'RESOLVED' ? '✓' : '✗';
      console.log(`  ${stateIcon} ${s.ticket}#${s.subissue_number} [${s.state}] ${s.title}`);
    }
  }
}

// Main
const options = parseArgs(process.argv.slice(2));

if (options.help) {
  showHelp();
  process.exit(0);
}

analyseComments(options);
