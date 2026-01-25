#!/usr/bin/env python3
"""
Validate Jac code blocks in documentation markdown files.

Extracts ```jac code blocks from markdown files and runs `jac check --parse-only`
to verify they have valid syntax. This catches syntax errors without requiring
imports or types to be resolvable.

Usage:
    python validate_docs_code.py [--docs-dir PATH] [--verbose]

Exit codes:
    0 - All code blocks pass validation
    1 - One or more code blocks failed validation
    2 - Script error (invalid arguments, missing dependencies)
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass
class CodeBlock:
    """Represents a code block extracted from a markdown file."""

    content: str
    file_path: str
    line_number: int


@dataclass
class ValidationResult:
    """Result of validating a code block."""

    code_block: CodeBlock
    success: bool
    error: str


def extract_code_blocks(file_path: Path) -> list[CodeBlock]:
    """Extract all jac code blocks from a markdown file."""
    code_blocks = []

    with open(file_path, encoding="utf-8") as f:
        lines = f.read().split("\n")

    # Pattern to match code blocks: ```jac or ```jac:something
    pattern = re.compile(r"^```(jac(?::\w+)?(?:\s+[^\n]*)?)\s*$")

    i = 0
    while i < len(lines):
        match = pattern.match(lines[i])
        if match:
            start_line = i + 1
            block_lines = []
            i += 1

            while i < len(lines) and not lines[i].startswith("```"):
                block_lines.append(lines[i])
                i += 1

            content = "\n".join(block_lines).strip()
            if content:
                code_blocks.append(
                    CodeBlock(
                        content=content,
                        file_path=str(file_path),
                        line_number=start_line,
                    )
                )
        i += 1

    return code_blocks


def validate_code_blocks(code_blocks: list[CodeBlock]) -> list[ValidationResult]:
    """Validate code blocks using jac check --parse-only."""
    if not code_blocks:
        return []

    results = []
    temp_dir = tempfile.mkdtemp(prefix="jac_parse_check_")
    temp_files = {}

    try:
        # Write all code blocks to temp files
        for i, block in enumerate(code_blocks):
            temp_path = os.path.join(temp_dir, f"block_{i}.jac")
            with open(temp_path, "w", encoding="utf-8") as f:
                f.write(block.content)
            temp_files[temp_path] = block

        # Run jac check --parse-only on all files
        all_paths = list(temp_files.keys())
        try:
            result = subprocess.run(
                ["jac", "check", "--parse_only"] + all_paths,
                capture_output=True,
                text=True,
                timeout=300,
            )

            output = (result.stdout or "") + (result.stderr or "")

            # Parse output to find which files had errors
            for temp_path, block in temp_files.items():
                filename = os.path.basename(temp_path)
                # Extract lines mentioning this file
                file_errors = [
                    line
                    for line in output.split("\n")
                    if filename in line or temp_path in line
                ]
                # Check if any error line contains "Error:"
                has_error = any("error" in line.lower() for line in file_errors)

                results.append(
                    ValidationResult(
                        code_block=block,
                        success=not has_error,
                        error="\n".join(file_errors) if has_error else "",
                    )
                )

        except subprocess.TimeoutExpired:
            for block in code_blocks:
                results.append(
                    ValidationResult(
                        code_block=block,
                        success=False,
                        error="Validation timed out",
                    )
                )
        except FileNotFoundError:
            print(
                "Error: jac command not found. Is jaclang installed?", file=sys.stderr
            )
            sys.exit(2)

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

    return results


# Files to skip validation (contain intentionally invalid syntax for demonstration)
SKIP_FILES = [
    "breaking-changes.md",  # Shows old/deprecated syntax examples
    "jsx_client_serv_design.md",  # Internal doc with JSX/client syntax
]


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Validate Jac code blocks in documentation (syntax only)",
    )
    parser.add_argument(
        "--docs-dir",
        type=Path,
        default=Path(__file__).parent.parent / "docs",
        help="Path to the docs directory (default: docs/docs)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Show verbose output",
    )
    parser.add_argument(
        "--file",
        "-f",
        type=Path,
        help="Validate a specific file instead of all docs",
    )

    args = parser.parse_args()

    # Determine which files to validate
    if args.file:
        if not args.file.exists():
            print(f"Error: File not found: {args.file}", file=sys.stderr)
            return 2
        markdown_files = [args.file]
    else:
        if not args.docs_dir.exists():
            print(f"Error: Docs directory not found: {args.docs_dir}", file=sys.stderr)
            return 2
        all_files = sorted(args.docs_dir.rglob("*.md"))
        markdown_files = [f for f in all_files if f.name not in SKIP_FILES]
        skipped = len(all_files) - len(markdown_files)
        if skipped > 0:
            print(f"Skipping {skipped} file(s) in exclusion list: {SKIP_FILES}")

    print(f"Checking syntax of Jac code blocks in {len(markdown_files)} files...")

    # Collect all code blocks
    all_blocks: list[CodeBlock] = []
    for md_file in markdown_files:
        blocks = extract_code_blocks(md_file)
        if blocks and args.verbose:
            print(f"  {md_file}: {len(blocks)} code block(s)")
        all_blocks.extend(blocks)

    if not all_blocks:
        print("No Jac code blocks found.")
        return 0

    print(f"Found {len(all_blocks)} code blocks, validating syntax...")

    # Validate
    results = validate_code_blocks(all_blocks)

    # Summarize
    passed = sum(1 for r in results if r.success)
    failed = len(results) - passed

    if failed > 0:
        print("\nFailed code blocks:")
        print("-" * 60)
        for r in results:
            if not r.success:
                print(f"\n{r.code_block.file_path}:{r.code_block.line_number}")
                print(f"  {r.error[:200]}..." if len(r.error) > 200 else f"  {r.error}")

    # Print summary at the end
    print()
    print("=" * 60)
    print(
        f"Results: {passed} passed, {failed} failed out of {len(results)} code blocks"
    )
    print("=" * 60)

    if failed > 0:
        return 1

    print("\n✓ All code blocks have valid syntax")
    return 0


if __name__ == "__main__":
    sys.exit(main())
