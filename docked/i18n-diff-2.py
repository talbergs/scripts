#!/usr/bin/env python3
"""
i18n-diff-2: Translation string comparison tool using tree-sitter

A robust tool for comparing translation strings between git commits in PHP projects.
Uses tree-sitter for accurate parsing and handles concatenated/multiline strings.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

try:
    from tree_sitter import Language, Parser, Node
    import tree_sitter_php as ts_php
except ImportError:
    print("Error: Required dependencies not found.", file=sys.stderr)
    print("Install with: pip install tree-sitter tree-sitter-php", file=sys.stderr)
    sys.exit(1)


@dataclass
class TranslationString:
    """Represents an extracted translation string"""
    text: str
    function: str
    context: Optional[str] = None
    plural: Optional[str] = None
    file: str = ""
    line: int = 0

    def __hash__(self):
        return hash((self.text, self.function, self.context, self.plural))

    def __eq__(self, other):
        if not isinstance(other, TranslationString):
            return False
        return (self.text == other.text and
                self.function == other.function and
                self.context == other.context and
                self.plural == other.plural)


class GitHelper:
    """Handles git operations and repository management"""

    @staticmethod
    def run_git(args: List[str], check: bool = True) -> subprocess.CompletedProcess:
        """Run a git command"""
        result = subprocess.run(
            ["git"] + args,
            capture_output=True,
            text=True,
            check=False
        )
        if check and result.returncode != 0:
            raise RuntimeError(f"Git command failed: {result.stderr}")
        return result

    @staticmethod
    def validate_ref(ref: str) -> bool:
        """Check if a git ref is valid"""
        result = GitHelper.run_git(["rev-parse", ref], check=False)
        return result.returncode == 0

    @staticmethod
    def get_default_branch() -> Optional[str]:
        """Detect the default branch of origin"""
        result = GitHelper.run_git(
            ["symbolic-ref", "refs/remotes/origin/HEAD"],
            check=False
        )
        if result.returncode == 0:
            return result.stdout.strip().replace("refs/remotes/origin/", "")

        for branch in ["main", "master", "develop"]:
            if GitHelper.validate_ref(f"origin/{branch}"):
                return branch
        return None

    @staticmethod
    def find_merge_base() -> Tuple[str, str]:
        """Auto-detect comparison refs based on branch history"""
        current_branch_result = GitHelper.run_git(
            ["rev-parse", "--abbrev-ref", "HEAD"]
        )
        current_branch = current_branch_result.stdout.strip()

        if current_branch == "HEAD":
            raise RuntimeError("Detached HEAD state. Please provide refs manually.")

        merge_commit_result = GitHelper.run_git(
            ["log", "--merges", "-n", "1", "--format=%H %P"],
            check=False
        )

        if merge_commit_result.returncode == 0 and merge_commit_result.stdout.strip():
            parts = merge_commit_result.stdout.strip().split()
            if len(parts) >= 3:
                merge_parent = parts[2]
                print(f"Found recent merge. Using merge point as comparison base.", file=sys.stderr)
                return merge_parent, "HEAD"

        default_branch = GitHelper.get_default_branch()
        if not default_branch:
            raise RuntimeError("Could not detect default branch. Please provide refs manually.")

        merge_base_result = GitHelper.run_git(
            ["merge-base", "HEAD", f"origin/{default_branch}"],
            check=False
        )

        if merge_base_result.returncode == 0:
            merge_base = merge_base_result.stdout.strip()
            print(f"Using merge-base with origin/{default_branch}", file=sys.stderr)
            return merge_base, "HEAD"

        raise RuntimeError("Could not auto-detect refs. Please provide them manually.")

    @staticmethod
    def find_ticket_range(ticket: str, ref: str = "HEAD") -> Tuple[str, str]:
        """Find commit range for a ticket by walking back history

        Walks back from ref until finding:
        - A commit without the ticket identifier, OR
        - A merge commit

        Returns (base_commit, latest_commit_with_ticket)
        """
        import re

        # Get all commits from ref walking backwards
        log_result = GitHelper.run_git([
            "log", ref, "--format=%H %s", "-n", "1000"
        ])

        commits = []
        for line in log_result.stdout.strip().split('\n'):
            if not line:
                continue
            parts = line.split(' ', 1)
            commit_hash = parts[0]
            commit_msg = parts[1] if len(parts) > 1 else ""
            commits.append((commit_hash, commit_msg))

        if not commits:
            raise RuntimeError(f"No commits found for ref: {ref}")

        # Find commits with the ticket identifier
        ticket_commits = []
        ticket_pattern = re.escape(ticket)

        for commit_hash, commit_msg in commits:
            if re.search(ticket_pattern, commit_msg, re.IGNORECASE):
                ticket_commits.append(commit_hash)
            elif ticket_commits:
                # Found first commit without ticket - this is our base
                print(f"Found {len(ticket_commits)} commits with ticket '{ticket}'", file=sys.stderr)
                print(f"Base commit (first without ticket): {commit_hash[:8]}", file=sys.stderr)
                print(f"Latest commit with ticket: {ticket_commits[0][:8]}", file=sys.stderr)
                return commit_hash, ticket_commits[0]

        # If we exhausted all commits and still have ticket commits,
        # check for merge commit within the ticket commits
        if ticket_commits:
            for commit_hash in ticket_commits:
                # Check if this is a merge commit
                parent_result = GitHelper.run_git(
                    ["rev-list", "--parents", "-n", "1", commit_hash],
                    check=False
                )
                if parent_result.returncode == 0:
                    parents = parent_result.stdout.strip().split()
                    if len(parents) > 2:  # Merge commits have 2+ parents
                        # Use the second parent (the merged branch)
                        base = parents[2] if len(parents) > 2 else parents[1]
                        print(f"Found {len(ticket_commits)} commits with ticket '{ticket}'", file=sys.stderr)
                        print(f"Base commit (merge parent): {base[:8]}", file=sys.stderr)
                        print(f"Latest commit with ticket: {ticket_commits[0][:8]}", file=sys.stderr)
                        return base, ticket_commits[0]

            # No merge found, use the commit before the oldest ticket commit
            if len(ticket_commits) < len(commits):
                base_commit = commits[len(ticket_commits)][0]
                print(f"Found {len(ticket_commits)} commits with ticket '{ticket}'", file=sys.stderr)
                print(f"Base commit: {base_commit[:8]}", file=sys.stderr)
                print(f"Latest commit with ticket: {ticket_commits[0][:8]}", file=sys.stderr)
                return base_commit, ticket_commits[0]

        raise RuntimeError(f"Could not find commits with ticket identifier: {ticket}")

    @staticmethod
    def extract_files(ref: str, target_dir: Path) -> List[Path]:
        """Extract PHP files from a git ref to target directory"""
        archive_path = target_dir / f"{ref}.tar"
        extract_dir = target_dir / ref

        GitHelper.run_git(["archive", ref, "-o", str(archive_path)])

        extract_dir.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["tar", "-xf", str(archive_path), "-C", str(extract_dir)],
            check=True,
            capture_output=True
        )

        php_files = list(extract_dir.rglob("*.php"))
        return php_files


class TranslationExtractor:
    """Extracts translation strings from PHP files using tree-sitter"""

    TRANSLATION_FUNCTIONS = {"_s", "_n", "_x", "_xs", "_xn"}

    def __init__(self):
        self.parser = Parser()
        # tree-sitter-php 0.23.0+ API
        try:
            # Try the new API first (0.23.0+)
            php_language = Language(ts_php.language_php())
        except AttributeError:
            try:
                # Fallback to older API
                php_language = Language(ts_php.language())
            except AttributeError:
                # Final fallback - direct language access
                import tree_sitter_php
                php_language = Language(tree_sitter_php.PHP_LANGUAGE)
        self.parser.language = php_language

    def parse_php_file(self, content: bytes) -> Optional[Node]:
        """Parse PHP file and return AST"""
        try:
            tree = self.parser.parse(content)
            return tree.root_node
        except Exception as e:
            print(f"Parse error: {e}", file=sys.stderr)
            return None

    def extract_string_literal(self, node: Node, source: bytes) -> Optional[str]:
        """Extract the string value from a string node"""
        if node.type == "string":
            string_content = node.text.decode('utf-8')
            if string_content.startswith('"') and string_content.endswith('"'):
                string_content = string_content[1:-1]
                string_content = string_content.replace('\\"', '"')
                string_content = string_content.replace('\\n', '\n')
                string_content = string_content.replace('\\t', '\t')
                return string_content
            elif string_content.startswith("'") and string_content.endswith("'"):
                string_content = string_content[1:-1]
                string_content = string_content.replace("\\'", "'")
                return string_content
        return None

    def extract_concatenated_string(self, node: Node, source: bytes) -> Optional[str]:
        """Recursively extract concatenated string literals"""
        if node.type == "string":
            return self.extract_string_literal(node, source)
        elif node.type == "binary_expression":
            operator_node = None
            for child in node.children:
                if child.type == ".":
                    operator_node = child
                    break

            if operator_node:
                left = None
                right = None
                for child in node.children:
                    if child.start_byte < operator_node.start_byte:
                        left = child
                    elif child.end_byte > operator_node.end_byte:
                        right = child
                        break

                if left and right:
                    left_str = self.extract_concatenated_string(left, source)
                    right_str = self.extract_concatenated_string(right, source)
                    if left_str is not None and right_str is not None:
                        return left_str + right_str
        return None

    def extract_argument(self, arg_node: Node, source: bytes) -> Optional[str]:
        """Extract string from argument node, handling concatenation"""
        result = self.extract_concatenated_string(arg_node, source)
        return result

    def find_translation_calls(self, root_node: Node, source: bytes, file_path: str) -> List[TranslationString]:
        """Find all translation function calls in the AST"""
        translations = []

        def traverse(node: Node):
            if node.type == "function_call_expression":
                name_node = node.child_by_field_name("function")
                if name_node and name_node.text.decode('utf-8') in self.TRANSLATION_FUNCTIONS:
                    func_name = name_node.text.decode('utf-8')
                    args_node = node.child_by_field_name("arguments")

                    if args_node:
                        args = []
                        for child in args_node.children:
                            if child.type == "argument":
                                arg_value = None
                                for sub in child.children:
                                    if sub.type != ",":
                                        arg_value = self.extract_argument(sub, source)
                                        break
                                args.append(arg_value)

                        trans = self._create_translation_string(
                            func_name, args, file_path, node.start_point[0]
                        )
                        if trans:
                            translations.append(trans)

            for child in node.children:
                traverse(child)

        traverse(root_node)
        return translations

    def _create_translation_string(
        self, func: str, args: List[Optional[str]], file: str, line: int
    ) -> Optional[TranslationString]:
        """Create a TranslationString from function call info"""
        if func == "_s" and len(args) >= 1 and args[0] is not None:
            return TranslationString(text=args[0], function=func, file=file, line=line)
        elif func == "_n" and len(args) >= 2 and args[0] is not None:
            return TranslationString(
                text=args[0],
                function=func,
                plural=args[1],
                file=file,
                line=line
            )
        elif func == "_x" and len(args) >= 2 and args[0] is not None:
            return TranslationString(
                text=args[0],
                function=func,
                context=args[1],
                file=file,
                line=line
            )
        elif func == "_xs" and len(args) >= 2 and args[0] is not None:
            return TranslationString(
                text=args[0],
                function=func,
                context=args[1],
                file=file,
                line=line
            )
        elif func == "_xn" and len(args) >= 4 and args[0] is not None:
            return TranslationString(
                text=args[0],
                function=func,
                plural=args[1],
                context=args[3],
                file=file,
                line=line
            )
        return None

    def extract_from_files(self, php_files: List[Path], base_dir: Path) -> Set[TranslationString]:
        """Extract translations from multiple PHP files"""
        all_translations = set()

        for php_file in php_files:
            try:
                content = php_file.read_bytes()
                root = self.parse_php_file(content)
                if root:
                    relative_path = php_file.relative_to(base_dir)
                    translations = self.find_translation_calls(root, content, str(relative_path))
                    all_translations.update(translations)
            except Exception as e:
                print(f"Error processing {php_file}: {e}", file=sys.stderr)

        return all_translations


class StringComparator:
    """Compares translation strings between two sets"""

    @staticmethod
    def compare(
        old_strings: Set[TranslationString],
        new_strings: Set[TranslationString]
    ) -> Tuple[Set[TranslationString], Set[TranslationString]]:
        """Return (added, removed) translation strings"""
        added = new_strings - old_strings
        removed = old_strings - new_strings
        return added, removed


class OutputFormatter:
    """Formats output in different formats"""

    @staticmethod
    def format_jira(added: Set[TranslationString], removed: Set[TranslationString]) -> str:
        """Format output in Jira-friendly markdown"""
        output = []

        if removed:
            output.append("Strings deleted:")
            for trans in sorted(removed, key=lambda t: t.text):
                if trans.context:
                    output.append(f"- _{trans.text}_ *context:* _{trans.context}_")
                elif trans.plural:
                    output.append(f"- _{trans.text}_ / _{trans.plural}_")
                else:
                    output.append(f"- _{trans.text}_")
            output.append("")

        if added:
            output.append("Strings added:")
            for trans in sorted(added, key=lambda t: t.text):
                if trans.context:
                    output.append(f"- _{trans.text}_ *context:* _{trans.context}_")
                elif trans.plural:
                    output.append(f"- _{trans.text}_ / _{trans.plural}_")
                else:
                    output.append(f"- _{trans.text}_")

        return "\n".join(output)

    @staticmethod
    def format_json(added: Set[TranslationString], removed: Set[TranslationString]) -> str:
        """Format output as JSON"""
        data = {
            "added": [
                {
                    "text": t.text,
                    "function": t.function,
                    "context": t.context,
                    "plural": t.plural,
                    "file": t.file,
                    "line": t.line
                }
                for t in sorted(added, key=lambda t: t.text)
            ],
            "removed": [
                {
                    "text": t.text,
                    "function": t.function,
                    "context": t.context,
                    "plural": t.plural,
                    "file": t.file,
                    "line": t.line
                }
                for t in sorted(removed, key=lambda t: t.text)
            ]
        }
        return json.dumps(data, indent=2, ensure_ascii=False)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Compare translation strings between git commits",
        epilog="Examples:\n"
               "  %(prog)s                    # Auto-detect refs\n"
               "  %(prog)s HEAD^ HEAD         # Compare last commit\n"
               "  %(prog)s --json abc123 HEAD # JSON output\n"
               "  %(prog)s --ticket PROJ-123  # Compare all commits with ticket\n",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("then_ref", nargs="?", help="Old git ref (auto-detected if not provided)")
    parser.add_argument("now_ref", nargs="?", help="New git ref (auto-detected if not provided)")
    parser.add_argument("--ticket", "-t", help="Ticket identifier to find commit range")
    parser.add_argument("--json", action="store_true", help="Output in JSON format")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")

    args = parser.parse_args()

    try:
        if args.ticket:
            # Ticket-based comparison mode
            if args.then_ref or args.now_ref:
                print("Error: Cannot use --ticket with explicit refs", file=sys.stderr)
                sys.exit(1)
            print(f"Finding commits for ticket: {args.ticket}", file=sys.stderr)
            then_ref, now_ref = GitHelper.find_ticket_range(args.ticket)
            print(f"Comparing: {then_ref[:8]} (base) -> {now_ref[:8]} (latest)", file=sys.stderr)
            print("", file=sys.stderr)
        elif args.then_ref and args.now_ref:
            then_ref = args.then_ref
            now_ref = args.now_ref
            if not GitHelper.validate_ref(then_ref):
                print(f"Error: Invalid ref '{then_ref}'", file=sys.stderr)
                sys.exit(2)
            if not GitHelper.validate_ref(now_ref):
                print(f"Error: Invalid ref '{now_ref}'", file=sys.stderr)
                sys.exit(2)
        elif not args.then_ref and not args.now_ref:
            print("Auto-detecting comparison refs...", file=sys.stderr)
            then_ref, now_ref = GitHelper.find_merge_base()
            print(f"Comparing: {then_ref} (base) -> {now_ref} (current)", file=sys.stderr)
            print("", file=sys.stderr)
        else:
            print("Error: Provide both refs or neither (for auto-detection)", file=sys.stderr)
            sys.exit(1)

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)

            if args.verbose:
                print(f"Extracting files from {then_ref}...", file=sys.stderr)
            then_files = GitHelper.extract_files(then_ref, tmp_path)

            if args.verbose:
                print(f"Extracting files from {now_ref}...", file=sys.stderr)
            now_files = GitHelper.extract_files(now_ref, tmp_path)

            extractor = TranslationExtractor()

            if args.verbose:
                print(f"Parsing {len(then_files)} files from {then_ref}...", file=sys.stderr)
            then_strings = extractor.extract_from_files(then_files, tmp_path / then_ref)

            if args.verbose:
                print(f"Parsing {len(now_files)} files from {now_ref}...", file=sys.stderr)
            now_strings = extractor.extract_from_files(now_files, tmp_path / now_ref)

            added, removed = StringComparator.compare(then_strings, now_strings)

            if args.json:
                print(OutputFormatter.format_json(added, removed))
            else:
                print(OutputFormatter.format_jira(added, removed))

    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted", file=sys.stderr)
        sys.exit(130)


if __name__ == "__main__":
    main()
