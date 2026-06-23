#!/usr/bin/env bash
# Fresh dev environment for the single-binary toolchain.
#
# jaclang ships as the one self-contained `jac` binary (Zig launcher + a private
# bundled CPython). There is NO pip-installed jaclang and no editable `.venv` for
# the language itself: to test a change to jac/jaclang you rebuild the binary
# (`cd jac && zig build`) and run `jac test`. The binary bundles the test runner
# (pytest + xdist), so `jac test` needs no system Python.
#
# Plugins (byllm/scale/mcp) are still ordinary Python packages: `jac install -e`
# drops their deps into each plugin's own project venv (.jac/venv) and links the
# source there; jaclang is provided by the binary, never installed into a venv.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Build the binary (needs zig 0.16.0 + zstd; the typeshed submodule must be
# checked out first).
git submodule update --init jac/jaclang/vendor/typeshed
( cd jac && zig build )

JAC_BIN="$PWD/jac/zig-out/bin/jac"
echo "Built: $JAC_BIN"
echo "Add it to PATH, e.g.:  export PATH=\"$PWD/jac/zig-out/bin:\$PATH\""
export PATH="$PWD/jac/zig-out/bin:$PATH"

# Plugins (editable): deps go into each plugin's own .jac/venv.
jac install -e jac-byllm
jac install -e jac-scale
jac install -e jac-mcp

# pre-commit is a standalone contributor tool (not part of the jac toolchain).
# Its jac hooks shell out to the `jac` binary on PATH, so all it needs is the
# binary above plus pre-commit itself. Install it however you prefer -- pipx is
# cleanest; otherwise a throwaway venv keeps it out of the system site.
if command -v pipx >/dev/null 2>&1; then
  pipx install pre-commit
else
  python3 -m venv .venv-precommit
  # shellcheck disable=SC1091
  source .venv-precommit/bin/activate
  pip install --quiet pre-commit
fi
pre-commit install
echo "Done. Ensure 'jac' stays on PATH for the pre-commit hooks."
