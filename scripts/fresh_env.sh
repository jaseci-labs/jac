#!/usr/bin/env bash
# Fresh dev environment for the single-binary toolchain.
#
# jaclang ships as the one self-contained `jac` binary (Zig launcher + a private
# bundled CPython). There is NO pip-installed jaclang and no editable `.venv` for
# the language itself. For an editable dev loop, set `[dev] jaclang_source = "jac"`
# in the root jac.toml so the binary runs the in-repo jac/jaclang source live --
# no rebuild per edit (see CONTRIBUTING.md). You only rebuild the binary
# (`cd jac && zig build`) for changes that live inside it (launcher .zig,
# sitecustomize.py / _jac_finder.py, bundled CPython). The binary bundles the
# test runner (pytest + xdist), so `jac test` needs no system Python.
#
# Plugins (byllm/scale/mcp) are still ordinary Python packages. We install them
# with `--global` so their source + deps land in the binary's own jac-owned site
# (never the host) and are importable from any directory -- including each
# plugin's own dir when you `cd jac-mcp && jac test .`. Without --global an
# editable install would target the current project's .jac/venv only, invisible
# from the plugin dirs. jaclang itself is provided by the binary, never installed.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Build the binary (needs zig 0.16.0 + network; no zstd/curl/git -- payload.zig
# does it all in std). zig build fetches the pinned typeshed stdlib stubs itself
# (the fetch-typeshed step), so there is no submodule to check out.
( cd jac && zig build -Dpayload-progress )

JAC_BIN="$PWD/jac/zig-out/bin/jac"
echo "Built: $JAC_BIN"
echo "Add it to PATH, e.g.:  export PATH=\"$PWD/jac/zig-out/bin:\$PATH\""
export PATH="$PWD/jac/zig-out/bin:$PATH"

# Plugins (editable, global): importable from anywhere, including each plugin dir.
jac install -e jac-byllm --global
jac install -e jac-scale --global
jac install -e jac-mcp --global

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
