#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

DEFAULT_ROOTS = (
    Path("jac/jaclang"),
    Path("jac-byllm/byllm"),
    Path("jac-client/jac_client"),
    Path("jac-scale/jac_scale"),
    Path("jac-streamlit/jaclang_streamlit"),
    Path("docs/docs/learn/examples"),
    Path("docs/docs/learn/tools/examples"),
)

EXCLUDE_SUBSTRINGS = (
    "/tests/",
    "/fixtures/",
    "/__pycache__/",
)


def iter_jac_files(roots: tuple[Path, ...]) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*.jac"):
            path_str = path.as_posix()
            if any(excl in path_str for excl in EXCLUDE_SUBSTRINGS):
                continue
            files.append(path)
    return sorted(files)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Format Jac sources using the repo's formatter + auto-lint."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Do not write files; exit non-zero if any would change.",
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Apply auto-lint fixes before formatting (recommended).",
    )
    parser.add_argument(
        "--roots",
        nargs="*",
        default=[str(p) for p in DEFAULT_ROOTS],
        help="Root directories to scan (defaults to the main Jac source trees).",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    jac_root = repo_root / "jac"
    if str(jac_root) not in sys.path:
        sys.path.insert(0, str(jac_root))

    try:
        from jaclang.pycore.program import JacProgram
    except Exception as exc:  # pragma: no cover
        print(f"Unable to import jaclang from {jac_root}: {exc}", file=sys.stderr)
        return 2

    roots = tuple((repo_root / r).resolve() for r in args.roots)
    jac_files = iter_jac_files(roots)
    if not jac_files:
        print("No .jac files found under configured roots.", file=sys.stderr)
        return 0

    changed: list[Path] = []
    failed: list[tuple[Path, list[str]]] = []
    for path in jac_files:
        prog = JacProgram.jac_file_formatter(str(path), auto_lint=bool(args.fix))
        if prog.errors_had:
            failed.append((path, [str(e) for e in prog.errors_had]))
            continue
        formatted = prog.mod.main.gen.jac
        original = prog.mod.main.source.code
        if formatted != original:
            changed.append(path)
            if not args.check:
                path.write_text(formatted, encoding="utf-8")

    for path, errors in failed:
        print(f"[error] {path}", file=sys.stderr)
        for msg in errors[:20]:
            print(f"  {msg}", file=sys.stderr)
        if len(errors) > 20:
            print("  ...", file=sys.stderr)

    if args.check:
        for path in changed:
            print(f"[needs-format] {path}", file=sys.stderr)

    if failed:
        print(f"Failed to format {len(failed)} file(s).", file=sys.stderr)
        return 2
    if args.check and changed:
        print(f"{len(changed)} file(s) would change.", file=sys.stderr)
        return 1
    if not args.check:
        print(f"Formatted {len(changed)}/{len(jac_files)} file(s).", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
