#!/usr/bin/env bash
# Fresh dev environment for the single-binary toolchain.
#
# jaclang ships as the one self-contained `jac` binary (Zig launcher + a private
# bundled CPython). There is NO pip-installed jaclang and no editable `.venv` for
# the language itself. This script builds a `jac` for the EDITABLE DEV LOOP with
# `zig build -Ddev`: the compiler is NOT bundled into the binary; instead the
# binary links the in-repo `jac/` source and runs it live, so day-to-day edits to
# jac/jaclang take effect with no rebuild. -Ddev also skips the JIR precompile and
# the ~100 MB compiler-tree copy, so this build is much faster than a release one.
# It still needs the LLVMPY_* shim placed in-tree (the compiler imports the native
# passes at startup), so we fetch+place LLVM once below -- same prerequisite as a
# release build, just not bundled into the binary. You only
# rebuild for changes that live inside the binary itself (launcher .zig,
# sitecustomize.py / _jac_finder.py, bundled CPython). The binary bundles the test
# runner (pytest + xdist), so `jac test` needs no system Python. For a fully
# self-contained release binary instead, run a plain `cd jac && zig build`.
#
# Plugins (byllm/scale/mcp) are still ordinary Python packages. We install them
# with `--global` so their source + deps land in the binary's own jac-owned site
# (never the host) and are importable from any directory -- including each
# plugin's own dir when you `cd jac-mcp && jac test .`. Without --global an
# editable install would target the current project's .jac/venv only, invisible
# from the plugin dirs. jaclang itself is provided by the binary, never installed.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Fetch the pinned LLVM once (idempotent; range-fetches only the ~84 MB subset the
# shim needs from the llvm-slice zip -- not the ~1 GB upstream tarball -- into
# jac/.llvm-build, ~0.35 GB on disk). The -Ddev build below compiles the LLVMPY_*
# shim from it and places it into jac/jaclang/compiler/passes/native/llvm/ where
# the linked compiler loads it.
( cd jac && zig build fetch-llvm )

# Place the pinned, contained bun runtime into the source tree
# (jac/jaclang/runtimelib/client/_bun) so the -Ddev linked binary below can
# resolve it for client/cl work via get_bun(). Release binaries bundle bun into
# the payload instead; this is the editable/source-checkout equivalent.
( cd jac && zig build fetch-bun )

# Build the dev binary (needs zig 0.16.0 + network; no zstd/curl/git -- payload.zig
# does it all in std). zig build fetches the pinned typeshed stdlib stubs itself
# (the fetch-typeshed step), so there is no submodule to check out. -Ddev links the
# compiler from this checkout instead of bundling it -- fast to build, edits run live.
( cd jac && zig build -Ddev -Dpayload-progress )

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
