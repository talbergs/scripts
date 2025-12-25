#!/usr/bin/env python3
"""
i18n-diff-2: Extract translation strings from PHP files at a git SHA

Accepts one or two git SHAs, extracts PHP files, parses translation strings,
and prints them as a list.
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Optional, Set

try:
    from tree_sitter import Language, Parser, Node
    import tree_sitter_php as ts_php
except ImportError:
    print("Error: Required dependencies not found.", file=sys.stderr)
    print("Install with: pip install tree-sitter tree-sitter-php", file=sys.stderr)
    sys.exit(1)


def run_git(args: List[str]) -> subprocess.CompletedProcess:
    """Run a git command"""
    result = subprocess.run(
        ["git"] + args,
        capture_output=True,
        text=True,
        check=False
    )
    if result.returncode != 0:
        raise RuntimeError(f"Git command failed: {result.stderr}")
    return result


def extract_files(ref: str, target_dir: Path) -> tuple[List[Path], Path]:
    """Extract PHP files from a git ref to target directory"""
    safe_ref = ref.replace('/', '-').replace('\\', '-')
    archive_path = target_dir / f"{safe_ref}.tar"
    extract_dir = target_dir / safe_ref

    run_git(["archive", ref, "-o", str(archive_path)])

    extract_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["tar", "-xf", str(archive_path), "-C", str(extract_dir)],
        check=True,
        capture_output=True
    )

    php_files = list(extract_dir.rglob("*.php"))
    return php_files, extract_dir


class TranslationExtractor:
    """Extracts translation strings from PHP files using tree-sitter"""

    TRANSLATION_FUNCTIONS = {"_s", "_n", "_x", "_xs", "_xn"}

    def __init__(self):
        self.parser = Parser()
        try:
            php_language = Language(ts_php.language_php())
        except AttributeError:
            try:
                php_language = Language(ts_php.language())
            except AttributeError:
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

    def extract_string_literal(self, node: Node) -> Optional[str]:
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
            return self.extract_string_literal(node)
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

    def find_translation_calls(self, root_node: Node, source: bytes) -> List[str]:
        """Find all translation function calls in the AST, return list of strings"""
        translations = []

        def traverse(node: Node):
            if node.type == "function_call_expression":
                name_node = node.child_by_field_name("function")
                if name_node and name_node.text.decode('utf-8') in self.TRANSLATION_FUNCTIONS:
                    args_node = node.child_by_field_name("arguments")

                    if args_node:
                        for child in args_node.children:
                            if child.type == "argument":
                                for sub in child.children:
                                    if sub.type != ",":
                                        text = self.extract_concatenated_string(sub, source)
                                        if text:
                                            translations.append(text)
                                        break
                                break  # Only extract first argument

            for child in node.children:
                traverse(child)

        traverse(root_node)
        return translations

    def extract_from_files(self, php_files: List[Path]) -> Set[str]:
        """Extract translations from multiple PHP files"""
        all_translations: Set[str] = set()

        for php_file in php_files:
            try:
                content = php_file.read_bytes()
                root = self.parse_php_file(content)
                if root:
                    translations = self.find_translation_calls(root, content)
                    all_translations.update(translations)
            except Exception as e:
                print(f"Error processing {php_file}: {e}", file=sys.stderr)

        return all_translations


def process_sha(sha: str) -> Set[str]:
    """Extract translation strings from a git SHA"""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)
        php_files, _ = extract_files(sha, tmp_path)
        extractor = TranslationExtractor()
        return extractor.extract_from_files(php_files)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Extract translation strings from PHP files at git SHAs",
        epilog="Examples:\n"
               "  %(prog)s abc123           # Extract strings from single SHA\n"
               "  %(prog)s abc123 def456    # Extract from both, show diff\n",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("from_sha", help="Git SHA to extract from")
    parser.add_argument("to_sha", nargs="?", help="Second git SHA (optional, shows diff)")

    args = parser.parse_args()

    try:
        from_strings = process_sha(args.from_sha)

        if args.to_sha:
            to_strings = process_sha(args.to_sha)
            added = to_strings - from_strings
            removed = from_strings - to_strings

            if removed:
                print("Removed:")
                for s in sorted(removed):
                    print(f"  - {s}")

            if added:
                print("Added:")
                for s in sorted(added):
                    print(f"  + {s}")
        else:
            for s in sorted(from_strings):
                print(s)

    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted", file=sys.stderr)
        sys.exit(130)


if __name__ == "__main__":
    main()
