#!/usr/bin/env node
/**
 * JIRA Version Check
 *
 * Analyzes git commit history to determine which release versions contain changes
 * for specific JIRA tickets. Tickets are identified by square bracket notation
 * in commit messages, e.g., [PROJ-123].
 *
 * Usage:
 *   node jira-version-check.js [options]
 *
 * Options:
 *   --input, -i        Input JSON file from jira-comments-analyse.js (default: ./jira-subissues.json)
 *   --output, -o       Output JSON file path (default: ./jira-versions.json)
 *   --repo, -r         Git repository path (default: current directory)
 *   --tag-pattern, -p  Regex pattern for version tags (default: v?\\d+\\.\\d+.*|.*rc.*)
 *   --defines, -d      Path to defines.inc.php for current version (optional)
 *   --tickets, -t      Comma-separated ticket IDs to check (overrides input file)
 *   --help, -h         Show this help message
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Output file format documentation
const FORMAT_DOCUMENTATION = {
  _format_version: "1.0",
  _format_description: "JIRA Ticket Version Availability",
  _format_schema: {
    metadata: {
      description: "Analysis metadata",
      fields: {
        analysed_at: "ISO 8601 timestamp of analysis",
        repository: "Path to git repository analysed",
        current_version: "Current version from defines.inc.php (if available)",
        total_versions: "Number of release versions found",
        total_tickets: "Number of tickets checked"
      }
    },
    versions: {
      description: "Array of version tags found",
      fields: {
        tag: "Git tag name",
        sha: "Full commit SHA",
        sha_short: "Short commit SHA (7 chars)",
        date: "Tag/commit date"
      }
    },
    tickets: {
      description: "Object keyed by ticket ID",
      fields: {
        ticket: "JIRA ticket key",
        available_in: "Array of versions containing this ticket's changes",
        commits: "Array of commits referencing this ticket",
        first_version: "Earliest version containing changes",
        summary: "Human-readable availability summary"
      }
    }
  }
};

function parseArgs(args) {
  const options = {
    inputFile: './jira-subissues.json',
    outputFile: './jira-versions.json',
    repoPath: '.',
    tagPattern: 'v?\\d+\\.\\d+.*|.*rc.*',
    definesPath: null,
    tickets: null,
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
    } else if (arg === '--repo' || arg === '-r') {
      options.repoPath = args[++i];
    } else if (arg === '--tag-pattern' || arg === '-p') {
      options.tagPattern = args[++i];
    } else if (arg === '--defines' || arg === '-d') {
      options.definesPath = args[++i];
    } else if (arg === '--tickets' || arg === '-t') {
      options.tickets = args[++i].split(',').map(t => t.trim());
    }
  }

  return options;
}

function showHelp() {
  const helpText = `
JIRA Version Check - Find which versions contain ticket changes

Usage:
  node jira-version-check.js [options]

Options:
  --input, -i <file>      Input JSON from jira-comments-analyse.js (default: ./jira-subissues.json)
  --output, -o <file>     Output JSON file path (default: ./jira-versions.json)
  --repo, -r <path>       Git repository path (default: current directory)
  --tag-pattern, -p <re>  Regex for version tags (default: v?\\d+\\.\\d+.*|.*rc.*)
  --defines, -d <file>    Path to defines.inc.php for current version
  --tickets, -t <list>    Comma-separated ticket IDs (overrides input file)
  --help, -h              Show this help message

Ticket Detection:
  Scans commit messages for square bracket notation:
    [PROJ-123] Fix authentication bug
    [PROJ-456][PROJ-789] Multi-ticket commit

Version Detection:
  Uses git tags matching the pattern. Default matches:
    - Semantic versions: v1.0.0, 2.1.3, v7.0
    - Release candidates: 7.0rc, 7.2.rc2, v1.0-rc1

Output Example:
  PROJ-123: Available in versions *7.0rc* (a1b2c3d), *7.2.rc2* (e4f5g6h)
`;
  console.log(helpText);
}

function exec(cmd, cwd) {
  try {
    return execSync(cmd, { cwd, encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 }).trim();
  } catch (err) {
    return '';
  }
}

function parseCurrentVersion(definesPath) {
  if (!definesPath || !fs.existsSync(definesPath)) {
    return null;
  }

  try {
    const content = fs.readFileSync(definesPath, 'utf8');

    // Common patterns for version in PHP defines
    const patterns = [
      /define\s*\(\s*['"]VERSION['"]\s*,\s*['"](.*?)['"]\s*\)/i,
      /define\s*\(\s*['"]APP_VERSION['"]\s*,\s*['"](.*?)['"]\s*\)/i,
      /\$version\s*=\s*['"](.*?)['"]/i,
      /const\s+VERSION\s*=\s*['"](.*?)['"]/i
    ];

    for (const pattern of patterns) {
      const match = content.match(pattern);
      if (match) {
        return match[1];
      }
    }
  } catch (err) {
    // Ignore errors
  }

  return null;
}

function getVersionTags(repoPath, tagPattern) {
  const pattern = new RegExp(tagPattern, 'i');

  // Get all tags with their commit info
  const tagsRaw = exec(
    'git tag --sort=-creatordate --format="%(refname:short)|%(objectname)|%(creatordate:iso)"',
    repoPath
  );

  if (!tagsRaw) {
    // Fallback: try simple tag list
    const simpleTags = exec('git tag --sort=-creatordate', repoPath);
    if (!simpleTags) return [];

    return simpleTags.split('\n').filter(tag => pattern.test(tag)).map(tag => {
      const sha = exec(`git rev-list -n 1 ${tag}`, repoPath);
      return {
        tag,
        sha,
        sha_short: sha.substring(0, 7),
        date: exec(`git log -1 --format=%ci ${tag}`, repoPath)
      };
    });
  }

  return tagsRaw
    .split('\n')
    .filter(line => line)
    .map(line => {
      const [tag, sha, date] = line.split('|');
      return { tag, sha, sha_short: sha.substring(0, 7), date };
    })
    .filter(v => pattern.test(v.tag));
}

function getCommitsForTicket(ticketKey, repoPath) {
  // Search for commits containing [TICKET-KEY] in message
  const escapedKey = ticketKey.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
  const pattern = `\\[${escapedKey}\\]`;

  const logOutput = exec(
    `git log --all --grep="${pattern}" --format="%H|%h|%s|%ci"`,
    repoPath
  );

  if (!logOutput) return [];

  return logOutput.split('\n').filter(line => line).map(line => {
    const [sha, sha_short, subject, date] = line.split('|');
    return { sha, sha_short, subject, date };
  });
}

function isCommitInVersion(commitSha, tagName, repoPath) {
  // Check if commit is an ancestor of the tag
  const result = exec(
    `git merge-base --is-ancestor ${commitSha} ${tagName} && echo "yes" || echo "no"`,
    repoPath
  );
  return result === 'yes';
}

function findVersionsForCommits(commits, versions, repoPath) {
  const availableIn = [];

  for (const version of versions) {
    for (const commit of commits) {
      if (isCommitInVersion(commit.sha, version.tag, repoPath)) {
        availableIn.push(version);
        break; // Only need to find one commit in this version
      }
    }
  }

  // Sort by date (oldest first)
  availableIn.sort((a, b) => new Date(a.date) - new Date(b.date));

  return availableIn;
}

function loadTicketsFromInput(inputFile) {
  if (!fs.existsSync(inputFile)) {
    return null;
  }

  try {
    const content = fs.readFileSync(inputFile, 'utf8');
    const data = JSON.parse(content);

    // Extract unique ticket IDs
    const tickets = new Set();
    if (data.subissues) {
      data.subissues.forEach(s => tickets.add(s.ticket));
    }
    if (data.by_ticket) {
      Object.keys(data.by_ticket).forEach(t => tickets.add(t));
    }

    return Array.from(tickets);
  } catch (err) {
    return null;
  }
}

function formatAvailabilitySummary(availableIn) {
  if (availableIn.length === 0) {
    return 'Not found in any release version';
  }

  const parts = availableIn.map(v => `*${v.tag}* (${v.sha_short})`);
  return `Available in versions ${parts.join(', ')}`;
}

async function checkVersions(options) {
  const repoPath = path.resolve(options.repoPath);

  // Verify git repo
  const isGitRepo = exec('git rev-parse --is-inside-work-tree', repoPath);
  if (isGitRepo !== 'true') {
    console.error(`Error: ${repoPath} is not a git repository`);
    process.exit(1);
  }

  console.log(`Analysing repository: ${repoPath}`);

  // Get current version from defines.inc.php
  const currentVersion = parseCurrentVersion(options.definesPath);
  if (currentVersion) {
    console.log(`Current version (from defines): ${currentVersion}`);
  }

  // Get version tags
  const versions = getVersionTags(repoPath, options.tagPattern);
  console.log(`Found ${versions.length} version tag(s)`);

  if (versions.length === 0) {
    console.warn('Warning: No version tags found matching pattern');
  }

  // Get tickets to check
  let tickets = options.tickets;
  if (!tickets) {
    tickets = loadTicketsFromInput(options.inputFile);
    if (!tickets || tickets.length === 0) {
      console.error('Error: No tickets to check. Provide --tickets or valid input file.');
      process.exit(1);
    }
  }

  console.log(`Checking ${tickets.length} ticket(s)...\n`);

  const results = {};

  for (const ticketKey of tickets) {
    process.stdout.write(`  ${ticketKey}... `);

    const commits = getCommitsForTicket(ticketKey, repoPath);

    if (commits.length === 0) {
      console.log('no commits found');
      results[ticketKey] = {
        ticket: ticketKey,
        commits: [],
        available_in: [],
        first_version: null,
        summary: 'No commits found referencing this ticket'
      };
      continue;
    }

    const availableIn = findVersionsForCommits(commits, versions, repoPath);

    console.log(`${commits.length} commit(s), ${availableIn.length} version(s)`);

    results[ticketKey] = {
      ticket: ticketKey,
      commits: commits.map(c => ({
        sha: c.sha_short,
        subject: c.subject,
        date: c.date
      })),
      available_in: availableIn.map(v => ({
        tag: v.tag,
        sha: v.sha_short,
        date: v.date
      })),
      first_version: availableIn.length > 0 ? availableIn[0].tag : null,
      summary: formatAvailabilitySummary(availableIn)
    };
  }

  const output = {
    ...FORMAT_DOCUMENTATION,
    metadata: {
      analysed_at: new Date().toISOString(),
      repository: repoPath,
      current_version: currentVersion,
      total_versions: versions.length,
      total_tickets: tickets.length
    },
    versions: versions.map(v => ({
      tag: v.tag,
      sha: v.sha_short,
      date: v.date
    })),
    tickets: results
  };

  fs.writeFileSync(options.outputFile, JSON.stringify(output, null, 2));

  // Print summary
  console.log('\n' + '─'.repeat(60));
  console.log('Version Availability Summary:\n');

  for (const ticketKey of tickets) {
    const r = results[ticketKey];
    console.log(`${ticketKey}: ${r.summary}`);
  }

  console.log('\n' + '─'.repeat(60));
  console.log(`Output: ${options.outputFile}`);
}

// Main
const options = parseArgs(process.argv.slice(2));

if (options.help) {
  showHelp();
  process.exit(0);
}

checkVersions(options).catch(err => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
