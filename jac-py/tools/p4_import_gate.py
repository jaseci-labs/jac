#!/usr/bin/env python3
"""P4 import-boundary gate (PLAN.md P0.3).

Static checks:
  - Product/front-end modules must not import the test-only host oracle.
  - Product modules must not use host marshal/tokenize/ast/compile bootstrap.

Transitional bootstrap policy (retire at P4 exit / PLAN.md P0.13):
  Modules that MAY use host compile/marshal until native front end lands:
    layer0_replay.jac, layer2_unittest.jac, layer3_import.jac, pyc_first.jac
  Product ceval module (PLAN.md §4 decomposition; ::py:: host bridge, not host_oracle):
    ceval.jac — callable/heap/proxy types + exec_code_frame; imports Objects leaf
  Test oracle bridge (test harness only, never product path):
    host_oracle.jac, layer4_compile.jac

Run from repo root:
    .venv/bin/python jac-py/tools/p4_import_gate.py
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

# Modules allowed to import host_oracle (test oracle + transitional bootstrap).
ALLOWED_HOST_ORACLE_IMPORTERS = {
    "layer4_compile.jac",
    "layer5_tokenizer.jac",
    "compiler_slice.jac",
    "layer8_product_expr.jac",
    "layer9_product_exec.jac",
    "layer10_product_controlflow.jac",
    "layer_vm_conformance.jac",
    "layer0_replay.jac",
    "layer2_unittest.jac",
    "layer3_import.jac",
    "pyc_first.jac",  # bootstrap duplicate bridge; retire at P4 exit
    "ceval.jac",  # product ceval (PLAN §4); ::py:: host bridge like pyc_first
    "host_oracle.jac",
}

FORBIDDEN_IMPORT = re.compile(
    r"^\s*import\s+(?:from\s+)?host_oracle\b", re.MULTILINE
)

# Product / P4 front-end module prefixes (extend as tokenizer/parser land).
PRODUCT_PREFIXES = (
    "product_compile",
    "ast_nodes",
    "token_model",
    "opcode_meta",
    "pycode_diff",
    "tokenizer",
    "peg",
    "parser",
    "symtable",
    "codegen",
    "assembler",
    "flowgraph",
    "compiler",
    "compiler_diagnostics",
    "compiler_validate",
    "compiler_symtable",
)

# Forbidden in product modules: host bootstrap imports and obvious host API use.
FORBIDDEN_PRODUCT_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"^\s*import\s+marshal\b", re.MULTILINE), "import marshal"),
    (re.compile(r"^\s*import\s+tokenize\b", re.MULTILINE), "import tokenize"),
    (re.compile(r"^\s*import\s+ast\b", re.MULTILINE), "import ast"),
    (re.compile(r"\bast\.parse\s*\(", re.MULTILINE), "ast.parse()"),
    (re.compile(r"\btokenize\.", re.MULTILINE), "tokenize.*"),
    (re.compile(r"(?<!_)compile\s*\(", re.MULTILINE), "compile()"),
)


def _repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(out.stdout.strip())


def _is_product_module(name: str) -> bool:
    return any(name.startswith(p) for p in PRODUCT_PREFIXES)


def _check_product_module(name: str, text: str) -> list[str]:
    errors: list[str] = []
    for pattern, label in FORBIDDEN_PRODUCT_PATTERNS:
        if pattern.search(text):
            errors.append(f"{name} contains forbidden host pattern: {label}")
    return errors


def main() -> int:
    root = _repo_root()
    jac_dir = root / "jac-py" / "jacpython"
    fail_msgs: list[str] = []
    for path in sorted(jac_dir.glob("*.jac")):
        if not path.is_file():
            continue
        text = path.read_text()
        name = path.name
        if name not in ALLOWED_HOST_ORACLE_IMPORTERS:
            if FORBIDDEN_IMPORT.search(text):
                fail_msgs.append(f"{name} imports host_oracle (not in allowlist)")
        if _is_product_module(name):
            fail_msgs.extend(_check_product_module(name, text))
    if fail_msgs:
        for msg in fail_msgs:
            print(f"FAIL: {msg}")
        return 1
    print("PASS: P4 import boundary")
    return 0


if __name__ == "__main__":
    sys.exit(main())
