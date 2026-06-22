#!/usr/bin/env bash
# Fresh dev environment. jaclang ships as the single `jac` binary (Zig launcher +
# bundled CPython) -- there is no pip-installed jaclang. Build the binary, put it
# on PATH, then install plugins (deps go into project venvs; jaclang is provided
# by the binary). The bundled test runner (`jac test`) ships pytest + xdist.
set -euo pipefail

# Build the binary (needs zig 0.16.0 + zstd; the typeshed submodule must be
# checked out: `git submodule update --init`).
( cd jac && zig build )

JAC_BIN="$PWD/jac/zig-out/bin/jac"
echo "Built: $JAC_BIN"
echo "Add it to PATH, e.g.:  export PATH=\"$PWD/jac/zig-out/bin:\$PATH\""
export PATH="$PWD/jac/zig-out/bin:$PATH"

# Plugins (editable): deps installed into each project's .jac/venv.
jac install -e jac-byllm
jac install -e jac-scale
jac install -e jac-mcp

# pre-commit is a Python dev tool; its jac hooks import jaclang from source via
# PYTHONPATH=jac, so a small venv just for pre-commit is enough.
python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
pip install pre-commit
pre-commit install
