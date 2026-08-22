#!/usr/bin/env python3
"""Recompile oracle golden sources and verify co_code / exceptiontable hex.

Uses the repo venv interpreter (CPython 3.14.x). Run from repo root:

    .venv/bin/python jac-py/tools/check_oracle_goldens.py
    .venv/bin/python jac-py/tools/check_oracle_goldens.py --stream b6_try_except_finally
"""
from __future__ import annotations

import argparse
import json
import sys
import types
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_GOLDENS = _HERE / "oracle_goldens"
_STREAMS = [
    "b6_try_except_finally",
    "b6_bare_except_else",
    "b6_raise_from",
    "b6_multi_with",
    "b7_generators",
    "b7_async",
]


def _find_code(co: types.CodeType, name: str) -> types.CodeType | None:
    if co.co_name == name:
        return co
    for const in co.co_consts:
        if isinstance(const, types.CodeType):
            found = _find_code(const, name)
            if found is not None:
                return found
    return None


def _load_fixtures(stream: str) -> list[dict]:
    path = _GOLDENS / stream / "paste_ready.json"
    if not path.is_file():
        path = _GOLDENS / stream / "goldens.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return data
    return list(data.get("fixtures", []))


def _code_hex(fx: dict) -> str:
    return fx.get("co_code_hex") or fx.get("co_code") or ""


def _tab_hex(fx: dict) -> str:
    return fx.get("co_exceptiontable_hex") or fx.get("co_exceptiontable") or ""


def check_stream(stream: str) -> list[str]:
    errors: list[str] = []
    fixtures = _load_fixtures(stream)
    if not fixtures:
        return [f"{stream}: no fixtures"]
    for fx in fixtures:
        name = fx.get("name", "<unnamed>")
        source = fx.get("source", "")
        if not source.strip():
            # degenerate try records SyntaxError text instead of code
            continue
        try:
            mod = compile(source, f"<{stream}:{name}>", "exec", dont_inherit=True)
        except SyntaxError as exc:
            # expected for the degenerate-try fixture
            if "expected 'except' or 'finally'" in str(exc):
                continue
            errors.append(f"{stream}/{name}: compile failed: {exc}")
            continue
        # Prefer nested function named in source, else first function const.
        co = None
        for const in mod.co_consts:
            if isinstance(const, types.CodeType) and const.co_name != "<module>":
                co = const
                break
        if co is None:
            co = mod
        want_code = _code_hex(fx)
        want_tab = _tab_hex(fx)
        got_code = co.co_code.hex()
        got_tab = co.co_exceptiontable.hex()
        if want_code and got_code != want_code:
            errors.append(
                f"{stream}/{name}: co_code mismatch (got {len(got_code)//2}B want {len(want_code)//2}B)"
            )
        if want_tab and got_tab != want_tab:
            errors.append(
                f"{stream}/{name}: exceptiontable mismatch (got {len(got_tab)//2}B want {len(want_tab)//2}B)"
            )
        want_stack = fx.get("co_stacksize")
        if want_stack is not None and co.co_stacksize != want_stack:
            errors.append(
                f"{stream}/{name}: stacksize {co.co_stacksize} != {want_stack}"
            )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stream", action="append", dest="streams")
    args = parser.parse_args(argv)
    streams = args.streams or _STREAMS
    all_errors: list[str] = []
    for stream in streams:
        if not (_GOLDENS / stream).is_dir():
            all_errors.append(f"missing stream dir: {stream}")
            continue
        errs = check_stream(stream)
        if errs:
            all_errors.extend(errs)
        else:
            print(f"PASS: {stream}")
    if all_errors:
        for err in all_errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1
    print(f"PASS: {len(streams)} oracle golden streams")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
