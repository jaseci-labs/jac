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
# scale, byLLM, and the MCP server are all built into the jac binary now
# (jaclang.scale / jaclang.byllm / jaclang.cli.mcp), so there are no separate
# plugin packages to install -- jaclang itself is provided by the binary. byLLM's
# heavy deps arrive per-project via the `llm` capability (`jac install`); install
# them globally below only if you want to run byLLM end-to-end from a fresh env.
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

# byLLM's `llm` capability deps (global so they're importable from anywhere).
# Pins mirror jac/jaclang/project/capabilities.jac. Optional: drop this line if
# you don't need to run `by llm()` flows in this env.
jac install \
  "litellm>=1.70.0,<=1.82.6" "pillow>=12.0.0,<13.0.0" \
  "httpx>=0.27.0" "loguru>=0.7.2,<0.8.0" \
  --global

# Local git hooks come from the jac binary itself: a pre-commit hook that
# formats/lints staged .jac files and a commit-msg hook that blocks AI
# co-author attribution. Markdown lint + the em-dash ban run on every PR via
# pre-commit.ci (see .pre-commit-config.yaml); nothing extra to install here.
jac precommit --install
echo "Done. Ensure 'jac' stays on PATH for the git hooks."
