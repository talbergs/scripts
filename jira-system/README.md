## Listing tickets.

Exec: `<repo>/jira-system/bin/jira-system --list-tickets`
Lists configured tickets with their cached titles and status.

Features:
- Displays all tickets from the configured tickets file
- Shows cached ticket data (summary, status, last sync time)
- Supports debug mode for detailed information (URL, comment count)
- Reads from local cache (requires prior `--ingest`)

Usage examples:
```bash
jira-system --list-tickets              # show all configured tickets
jira-system --list-tickets --debug      # include extra details
```

Display includes:
- Ticket key (e.g., PROJ-123)
- Title/Summary
- Current status
- Last sync time
- Debug: Direct JIRA URL and comment count

- Inputs: `~/.config/jira-system/tickets.tsv`, `~/.cache/jira-system/ingestion.tickets.json`
- Outputs: Formatted table to stdout

## Ingestion.

Exec: `<repo>/jira-system/bin/jira-system --ingest`
System periodically or on demand ingests information from Jira about tickets listed in `~/.config/jira-system/tickets.tsv` file.
- if file does not exist, create file with "DEMO-123" as contents
- if file contents are "DEMO-123" then notify user and exit with warning message specifying where to maintain tickets list.
- if file is empty exit with warning message specifying where to maintain tickets list.
- Inputs: env: `JIRA_BASE_URL` (optional), `JIRA_PAT` (mandatory)
- Inputs: `~/.config/jira-system/tickets.tsv` (TSV format, first column = ticket ID)
- Outputs: `~/.cache/jira-system/ingestion.tickets.json` (owned)

## Subissues extraction.

Exec: `<repo>/jira-system/bin/jira-system --extract-subissues`
Extracts subissues from ingested tickets.

Subissue is numbered jira comment, such that comment message starts with "(<digit>)" - styled or not, i.e - `"(2)", "*(77)*", "(*21*)"`.
Subissue has:
- opener (comment creator)
- status (OPEN, CLOSED, REOPENED, RESOLVED, MOVED) - if any of these caps keywords appear last in subissue body, that's the current status of the subissue
- metadata - created at, last updated at
- status_history - list of dated subissue state changes along with the full comment body before and after the status change

- Inputs: `~/.cache/jira-system/ingestion.tickets.json`
- Outputs: `~/.cache/jira-system/ingestion.tickets.subissues.json` (owned)

## Adding subissues.

Exec: `<repo>/jira-system/bin/jira-system --add-subissue [TICKET] [DESCRIPTION]`
Creates a new subissue comment on a JIRA ticket with automatic numbering.

Features:
- Automatically fetches latest ticket state from JIRA
- Analyzes existing subissues to determine next available number
- Posts comment with "Developers" group visibility by default (restricted viewing)
- Creates local edit file for future daemon sync
- Supports git branch inference for ticket key

Usage examples:
```bash
jira-system --add-subissue PROJ-123 "Fix the login validation"           # explicit ticket
jira-system --add-subissue "Fix the login validation"                    # infer from git branch
jira-system --add-subissue                                               # fully interactive
jira-system --debug --add-subissue PROJ-123 "Test change"               # show detailed steps
```

Behavior:
- Infers ticket key from git branch name if not provided (e.g., `feature/PROJ-123-fix` → `PROJ-123`)
- Fetches all comments from the ticket
- Extracts existing subissues (numbered comments: `(1)`, `(2)`, etc.)
- Assigns next available number (e.g., if subissues 1, 3, 5 exist → next is 6)
- Posts comment with visibility restricted to "Developers" group
- Creates local file at `~/.cache/jira-system/edit.subissue/TICKET/NUMBER.txt`

- Inputs: JIRA ticket key, description text; fetches from JIRA API
- Outputs: Posted comment on JIRA ticket, local edit file

## Coordination.

Exec: `<repo>/jira-system/bin/jira-system --daemon`
System has optional daemon that may be used. Default process:
- Checks last modified timestamp on file `~/.cache/jira-system/ingestion.tickets.json`
- Maintains the timestamp in own sqlite file in `~/.cache/jira-system/coordination.sqlite` in table "ingestion" column "tickets" as unix timestamp.
- if timestamp in db and has changed, invoke the `<repo>/jira-system/bin/jira-system --handle-ingestion-tickets`
    - handler for `ingestion-tickets` event is the sequence of action calls: `extract.tickets.subissues`, `extract.tickets.overview`
- Inputs: `~/.cache/jira-system/ingestion.tickets.json` (owned)
- Outputs: `~/.cache/jira-system/ingestion.tickets.subissues.json` (owned)

## Authentication verification.

Exec: `<repo>/jira-system/bin/jira-system --check-auth`
Verifies JIRA API access and authentication configuration.

Checks performed:
1. API connectivity - attempts to connect to JIRA API
2. Token validation - verifies authentication credentials
3. Tickets file - checks if configured tickets file exists and is readable
4. Sample ticket fetch - attempts to fetch the first configured ticket to validate permissions

Output:
- Shows authenticated user details (if available)
- Lists configured tickets
- Tests read access to a sample ticket
- Provides clear pass/fail status

Usage:
```bash
jira-system --check-auth              # basic connectivity check
jira-system --check-auth --debug      # show detailed API requests
```

# CLI Options.

- `--debug`, `-d` - Enable verbose debug mode (show env, URLs, request/response details, payloads)
- `--help`, `-h` - Show help message

# JSON Schema and Composability.

All output files include embedded format documentation:
- `_format_version` - Schema version for compatibility checking
- `_format_description` - Human-readable description of the file purpose
- `_format_schema` - Complete field documentation

Each command reads from and writes to specific files, enabling pipelines:
```
--ingest -> ingestion.tickets.json -> --extract-subissues -> ingestion.tickets.subissues.json
```

Output files are designed for downstream tooling (jq, scripts, other processors).

# Future vector.

Automatically update the comment in jira for the ticket using a file supporting history and threads. Utilizes ticket change-log trail. Supports drafts.

# User stories.

> User wants to easily close subissue, if needed.

- subscribe to such event: "A ticket subissue changed (i.e. in ZBXNEXT-9731 subissue (36) changed into RESOLVED state AND is changed not by you)."
- meaaning, subscribe on such event expression: "on:subissue:change ZBXNEXT-9731/subissue/36"
- user opens vim and edits the `~/.cache/jira-system/edit.subissue/ZBXNEXT-9731/36.txt` file
- later the coordination daemon will use JIRA_PAT and invoke appropriate script/command to update the comment also in jira, checking for changes again, right before submiting the updated comment body.

> User wants to easily add a subissue
- user adds file in the `~/.cache/jira-system/edit.subissue/ZBXNEXT-9731/<number>.txt` location.

# Other.
- Reset daemon
    - `<repo>/jira-system/bin/jira-system --reset-daemon`
        - implicitly `rm ~/.cache/jira-system/coordination.sqlite` && `<repo>/jira-system/bin/jira-system --restart-daemon`
