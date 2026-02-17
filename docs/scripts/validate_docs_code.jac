"""
Validate Jac code blocks in documentation markdown files.

Extracts ```jac code blocks from markdown files and runs `jac check --parse-only`
to verify they have valid syntax. This catches syntax errors without requiring
imports or types to be resolvable.

Usage:
    jac run docs/scripts/validate_docs_code.jac [-- --docs-dir PATH] [-- --verbose]

Exit codes:
    0 - All code blocks pass validation
    1 - One or more code blocks failed validation
    2 - Script error (invalid arguments, missing dependencies)
"""

import argparse;
import os;
import re;
import shutil;
import subprocess;
import sys;
import tempfile;
import from dataclasses { dataclass }
import from pathlib { Path }

@dataclass
obj CodeBlock {
    """Represents a code block extracted from a markdown file."""
    has content: str,
        file_path: str,
        line_number: int;
}

@dataclass
obj ValidationResult {
    """Result of validating a code block."""
    has code_block: CodeBlock,
        success: bool,
        error: str;
}

"""Extract all jac code blocks from a markdown file."""
def extract_code_blocks(file_path: Path) -> list[CodeBlock] {
    code_blocks: list[CodeBlock] = [];
    with open(file_path, encoding="utf-8") as f {
        lines = f.read().split("\n");
    }
    pattern = re.compile(r"^```(jac(?::\w+)?(?:\s+[^\n]*)?)\s*$");
    i = 0;
    while i < len(lines) {
        m = pattern.match(lines[i]);
        if m {
            start_line = i + 1;
            block_lines: list[str] = [];
            i += 1;
            while i < len(lines) and not lines[i].startswith("```") {
                block_lines.append(lines[i]);
                i += 1;
            }
            content = "\n".join(block_lines).strip();
            if content {
                code_blocks.append(
                    CodeBlock(
                        content=content,
                        file_path=str(file_path),
                        line_number=start_line,
                    )
                );
            }
        }
        i += 1;
    }
    return code_blocks;
}

"""Validate code blocks using jac check --parse-only."""
def validate_code_blocks(code_blocks: list[CodeBlock]) -> list[ValidationResult] {
    if not code_blocks {
        return [];
    }
    results: list[ValidationResult] = [];
    temp_dir = tempfile.mkdtemp(prefix="jac_parse_check_");
    temp_files: dict = {};
    try {
        for (i, block) in enumerate(code_blocks) {
            temp_path = os.path.join(temp_dir, f"block_{i}.jac");
            with open(temp_path, "w", encoding="utf-8") as f {
                f.write(block.content);
            }
            temp_files[temp_path] = block;
        }
        all_paths = list(temp_files.keys());
        try {
            result = subprocess.run(
                ["jac", "check", "--parse_only"] + all_paths,
                capture_output=True,
                text=True,
                timeout=300,
            );
            output = (result.stdout or "") + (result.stderr or "");
            for (temp_path, block) in temp_files.items() {
                filename = os.path.basename(temp_path);
                file_errors = [
                    line
                    for line in output.split("\n")
                    if filename in line or temp_path in line
                ];
                has_error = any("error" in line.lower() for line in file_errors);
                results.append(
                    ValidationResult(
                        code_block=block,
                        success=not has_error,
                        error="\n".join(file_errors) if has_error else "",
                    )
                );
            }
        } except subprocess.TimeoutExpired {
            for block in code_blocks {
                results.append(
                    ValidationResult(
                        code_block=block, success=False, error="Validation timed out",
                    )
                );
            }
        } except FileNotFoundError {
            print(
                "Error: jac command not found. Is jaclang installed?", file=sys.stderr
            );
            sys.exit(2);
        }
    } finally {
        shutil.rmtree(temp_dir, ignore_errors=True);
    }
    return results;
}

glob SKIP_FILES = ["breaking-changes.md", "jsx_client_serv_design.md", ],
     parser = argparse.ArgumentParser(
         description="Validate Jac code blocks in documentation (syntax only)",
     );

with entry {
    parser.add_argument(
        "--docs-dir",
        type=Path,
        default=Path(__file__).parent.parent / "docs",
        help="Path to the docs directory (default: docs/docs)",
    );
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Show verbose output"
    );
    parser.add_argument(
        "--file", "-f", type=Path, help="Validate a specific file instead of all docs"
    );
}

glob args = parser.parse_known_args()[0];

with entry {
    if args.file {
        if not args.file.exists() {
            print(f"Error: File not found: {args.file}", file=sys.stderr);
            sys.exit(2);
        }
        markdown_files = [args.file];
    } else {
        if not args.docs_dir.exists() {
            print(f"Error: Docs directory not found: {args.docs_dir}", file=sys.stderr);
            sys.exit(2);
        }
        all_files = sorted(args.docs_dir.rglob("*.md"));
        markdown_files = [
            f
            for f in all_files
            if f.name not in SKIP_FILES
        ];
        skipped = len(all_files) - len(markdown_files);
        if skipped > 0 {
            print(f"Skipping {skipped} file(s) in exclusion list: {SKIP_FILES}");
        }
    }

    print(f"Checking syntax of Jac code blocks in {len(markdown_files)} files...");
}

glob all_blocks: list[CodeBlock] = [];

with entry {
    for md_file in markdown_files {
        blocks = extract_code_blocks(md_file);
        if blocks and args.verbose {
            print(f"  {md_file}: {len(blocks)} code block(s)");
        }
        all_blocks.extend(blocks);
    }

    if not all_blocks {
        print("No Jac code blocks found.");
        sys.exit(0);
    }

    print(f"Found {len(all_blocks)} code blocks, validating syntax...");
}

glob results = validate_code_blocks(all_blocks),
     passed = sum(
         1
         for r in results
         if r.success
     ),
     failed = len(results) - passed;

with entry {
    if failed > 0 {
        print("\nFailed code blocks:");
        print("-" * 60);
        for r in results {
            if not r.success {
                print(f"\n{r.code_block.file_path}:{r.code_block.line_number}");
                if len(r.error) > 200 {
                    print(f"  {r.error[:200]}...");
                } else {
                    print(f"  {r.error}");
                }
            }
        }
    }

    print();
    print("=" * 60);
    print(
        f"Results: {passed} passed, {failed} failed out of {len(results)} code blocks"
    );
    print("=" * 60);

    if failed > 0 {
        sys.exit(1);
    }
    print("\n✓ All code blocks have valid syntax");
}
