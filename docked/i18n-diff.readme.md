# i18n-diff

A Dockerized tool for extracting and comparing translation strings from PHP files using tree-sitter.

## Overview

i18n-diff extracts gettext function calls from PHP codebases and compares them between two git refs. This helps identify new strings that need translation and removed strings that can be cleaned up.

### Supported Functions

| Function | Extracted Arguments | Description |
|----------|-------------------|-------------|
| `_s(msgid)` | arg 1 | Simple translation |
| `_n(singular, plural, n)` | args 1, 2 | Pluralization |
| `_x(msgid, context)` | arg 1 | Contextual translation |
| `_xs(msgid, context)` | arg 1 | Contextual translation (variant) |
| `_xn(singular, plural, n, context)` | args 1, 2 | Contextual pluralization |

## Requirements

- Docker
- Git repository with PHP files

## Installation

Clone the repository and build the Docker image:

```bash
./i18n-diff.build.sh
```

## Usage

### Basic Usage

Run from within a git repository:

```bash
./i18n-diff.dockerized.sh
```

This auto-detects the ticket tag from the HEAD commit message (looks for `[TAG]` pattern) and finds the base commit.

### Compare Specific Refs

```bash
./i18n-diff.dockerized.sh HEAD~3 HEAD
./i18n-diff.dockerized.sh release/7.4 master
./i18n-diff.dockerized.sh origin/main HEAD
```

### Output

The tool outputs:
- **Removed:** Strings present in base but not in head (translations deleted)
- **Added:** Strings present in head but not in base (new translations needed)

Results are also written to:
- `/tmp/i18n-diff/result/ref1.list` - Sorted strings from base ref
- `/tmp/i18n-diff/result/ref2.list` - Sorted strings from head ref

### Direct Script Options

When running the script directly (inside Docker):

```
Usage: i18n-diff.sh [OPTIONS]

Options:
    -1, --ref1 DIR     Base/old reference directory (default: /base_sha)
    -2, --ref2 DIR     Head/new reference directory (default: /head_sha)
    -o, --output DIR   Output directory (default: /result)
    -q, --query FILE   Tree-sitter query file
    -d, --diff         Show diff between ref1 and ref2
    -h, --help         Show help message
```

## How It Works

1. Extracts PHP files from each git ref using `git archive`
2. Parses PHP files with tree-sitter using a custom query (`i18n-php-gettext.scm`)
3. Extracts string literals from translation function calls
4. Handles string concatenation (`"foo" . "bar"`) and escape sequences
5. Compares sorted, deduplicated string lists using `comm`

## Testing

Run the test suite:

```bash
./i18n-diff.test.sh
```

## Project Structure

```
i18n-diff.sh           # Main extraction script
i18n-diff.dockerized.sh # Docker wrapper with git integration
i18n-diff.build.sh     # Docker image build script
i18n-diff.test.sh      # Test suite
i18n-diff.Dockerfile   # Multi-stage Docker build
i18n-php-gettext.scm   # Tree-sitter query for PHP gettext functions
```

## Docker Image

The image is built in two stages:
1. **Builder stage:** Compiles tree-sitter CLI and PHP grammar from source
2. **Runtime stage:** Minimal Alpine image with bash and the compiled tools

The final image contains:
- tree-sitter CLI (v0.22.6)
- tree-sitter-php grammar
- The extraction script and query file
