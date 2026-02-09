#!/usr/bin/env python3
"""Walk the repo and compare Lark vs RD parser ASTs on every .jac file.

Usage:
    python rd_parser_walk_check.py [ROOT_DIR]

If ROOT_DIR is omitted it defaults to the current working directory.

For each .jac file found via os.walk the script:
  1. Tries to parse with both the Lark-based parser and the RD parser.
  2. If both succeed, canonicalizes the ASTs and compares them.
  3. Prints a per-file status and a final summary.

Exit code 0 = all parseable files match, 1 = mismatches found.
"""

import os
import sys
from difflib import unified_diff

from jaclang.pycore.jac_parser import JacParser
from jaclang.pycore.program import JacProgram
from jaclang.pycore.unitree import (
    FString,
    JsxText,
    Module,
    Source,
    String,
    Token,
    UniNode,
)
from jaclang.pycore.unitree import Test as JacTest
from jaclang.runtimelib.utils import read_file_with_encoding

# -- AST canonicalization (mirrors test_rd_parser_validation.py) ---------------


def canonicalize(node: UniNode, indent: int = 0, in_jsx_text: bool = False) -> str:
    prefix = "  " * indent
    if isinstance(node, Token):
        value = node.value.strip() if in_jsx_text else node.value
        return f"{prefix}{node.__class__.__name__}: {value!r}\n"

    is_jsx_text = isinstance(node, JsxText)
    if is_jsx_text and all(
        isinstance(c, Token) and c.value.strip() == "" for c in node.kid
    ):
        return ""
    if is_jsx_text and all(
        isinstance(c, Token) and c.value.strip().startswith("#") for c in node.kid
    ):
        return ""

    lines = f"{prefix}{node.__class__.__name__}\n"
    children = list(node.kid)
    if isinstance(node, FString):
        child_prefix = "  " * (indent + 1)
        i = 0
        while i < len(children):
            child = children[i]
            if isinstance(child, String):
                merged_value = child.value
                while i + 1 < len(children) and isinstance(children[i + 1], String):
                    i += 1
                    merged_value += children[i].value  # type: ignore[attr-defined]
                lines += f"{child_prefix}String: {merged_value!r}\n"
            else:
                lines += canonicalize(child, indent + 1, in_jsx_text=is_jsx_text)
            i += 1
        return lines

    for child in children:
        lines += canonicalize(child, indent + 1, in_jsx_text=is_jsx_text)
    return lines


# -- Parsing helpers -----------------------------------------------------------


def parse_with_lark(source: str, file_path: str) -> Module | None:
    try:
        prse = JacParser(
            root_ir=Source(source, mod_path=file_path),
            prog=JacProgram(),
        )
        if prse.errors_had:
            return None
        return prse.ir_out
    except Exception:
        return None


def parse_with_rd(source: str, file_path: str) -> Module | None:
    try:
        from jaclang.compiler.parser.parser import parse

        module, parse_errors, lex_errors = parse(source, file_path)
        if lex_errors or parse_errors:
            return None
        return module
    except Exception:
        return None


# -- Main walk -----------------------------------------------------------------


def main() -> int:
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    print(f"Scanning for .jac files under: {root}\n")

    total = 0
    matched = 0
    mismatched = 0
    lark_only = 0
    rd_only = 0
    both_fail = 0
    mismatch_files: list[str] = []

    for dirpath, dirnames, filenames in os.walk(root):
        # Skip hidden dirs, __pycache__, .venv, node_modules, etc.
        dirnames[:] = [
            d
            for d in dirnames
            if not d.startswith(".")
            and d not in ("__pycache__", "node_modules", ".venv")
        ]
        for fname in sorted(filenames):
            if not fname.endswith(".jac"):
                continue
            filepath = os.path.join(dirpath, fname)
            total += 1
            rel = os.path.relpath(filepath, root)

            try:
                source = read_file_with_encoding(filepath)
            except Exception as exc:
                print(f"  SKIP  {rel}  (read error: {exc})")
                both_fail += 1
                continue

            saved_test_count = JacTest.TEST_COUNT
            lark_ast = parse_with_lark(source, filepath)
            JacTest.TEST_COUNT = saved_test_count
            rd_ast = parse_with_rd(source, filepath)

            if lark_ast is None and rd_ast is None:
                print(f"  BOTH_FAIL  {rel}")
                both_fail += 1
            elif lark_ast is None:
                print(f"  RD_ONLY    {rel}")
                rd_only += 1
            elif rd_ast is None:
                print(f"  LARK_ONLY  {rel}")
                lark_only += 1
            else:
                lark_canon = canonicalize(lark_ast)
                rd_canon = canonicalize(rd_ast)
                if lark_canon == rd_canon:
                    print(f"  MATCH      {rel}")
                    matched += 1
                else:
                    print(f"  MISMATCH   {rel}")
                    mismatched += 1
                    mismatch_files.append(rel)

    # -- Summary ---------------------------------------------------------------
    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)
    print(f"  Total .jac files : {total}")
    print(f"  AST match        : {matched}")
    print(f"  AST mismatch     : {mismatched}")
    print(f"  Lark-only parse  : {lark_only}")
    print(f"  RD-only parse    : {rd_only}")
    print(f"  Both fail        : {both_fail}")

    if mismatch_files:
        print(f"\nMismatched files ({len(mismatch_files)}):")
        for f in mismatch_files:
            print(f"  - {f}")

    if mismatched:
        print("\nRe-run with --diff to see AST diffs for mismatched files.")

    # -- Optional diff output --------------------------------------------------
    if "--diff" in sys.argv and mismatch_files:
        for rel in mismatch_files:
            filepath = os.path.join(root, rel)
            source = read_file_with_encoding(filepath)
            saved = JacTest.TEST_COUNT
            lark_ast = parse_with_lark(source, filepath)
            JacTest.TEST_COUNT = saved
            rd_ast = parse_with_rd(source, filepath)
            if lark_ast and rd_ast:
                lark_canon = canonicalize(lark_ast)
                rd_canon = canonicalize(rd_ast)
                diff = "\n".join(
                    unified_diff(
                        lark_canon.splitlines(),
                        rd_canon.splitlines(),
                        fromfile=f"lark:{rel}",
                        tofile=f"rd:{rel}",
                        lineterm="",
                    )
                )
                print(f"\n{'─' * 60}")
                print(f"DIFF: {rel}")
                print(f"{'─' * 60}")
                print(diff)

    return 1 if mismatched else 0


if __name__ == "__main__":
    sys.exit(main())
