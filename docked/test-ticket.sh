#!/bin/bash
#
# Test the ticket-based comparison feature
#
# This script creates a test repository with ticket-tagged commits
# and verifies that the ticket detection works correctly.

set -e

TEST_DIR="/tmp/i18n-diff-ticket-test-$$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/i18n-diff-2.py"

echo "======================================"
echo "Ticket-based Comparison Test"
echo "======================================"
echo ""

# Setup test repository
echo "Creating test repository..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create initial state
cat > file.php <<'EOF'
<?php
_s("Original String");
EOF

git add file.php
git commit -m "Initial commit"

# Create commits with ticket PROJ-123
cat > file.php <<'EOF'
<?php
_s("Original String");
_s("Feature String 1");
EOF

git add file.php
git commit -m "PROJ-123: Add first feature string"

cat > file.php <<'EOF'
<?php
_s("Original String");
_s("Feature String 1");
_s("Feature String 2");
EOF

git add file.php
git commit -m "PROJ-123: Add second feature string"

cat > file.php <<'EOF'
<?php
_s("Original String");
_s("Feature String 1");
_s("Feature String 2");
_s("Feature String 3");
EOF

git add file.php
git commit -m "PROJ-123 - Add third feature string"

# Create a commit with a different ticket
cat > other.php <<'EOF'
<?php
_s("Different ticket string");
EOF

git add other.php
git commit -m "PROJ-456: Different feature"

echo ""
echo "Test repository created with commits:"
git log --oneline

echo ""
echo "======================================"
echo "Testing ticket detection..."
echo "======================================"
echo ""

# Test the ticket detection
python3 "$PYTHON_SCRIPT" --ticket "PROJ-123" --verbose

echo ""
echo "======================================"
echo "Expected behavior:"
echo "- Should find 3 commits with PROJ-123"
echo "- Should compare from 'Initial commit' to last PROJ-123 commit"
echo "- Should show 3 added strings (Feature String 1, 2, 3)"
echo "- Should NOT show 'Different ticket string' (belongs to PROJ-456)"
echo "======================================"

# Cleanup
cd /
rm -rf "$TEST_DIR"

echo ""
echo "Test complete!"
