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

# The -Ddev binary needs the LLVMPY_* shim placed in-tree. Prefer a prebuilt,
# per-platform shim published by release-jacllvm.yml (a ~110 MB download) over
# fetching ~0.35 GB of LLVM and linking it here. Best-effort: any miss (unknown
# platform, uncommitted shim edits, no matching asset, network/verify failure)
# falls through to the from-source path below -- the prebuilt is never a hard dep.
SHIM_BIN=""
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  JACLLVM_PLATFORM=linux-x86_64 ;;
  Linux-aarch64) JACLLVM_PLATFORM=linux-aarch64 ;;
  Darwin-arm64)  JACLLVM_PLATFORM=macos-aarch64 ;;
  *)             JACLLVM_PLATFORM="" ;;
esac
# Gate on a clean worktree for the shim inputs: the id is computed from HEAD, so
# any local change -- staged, unstaged, OR untracked (e.g. a new native/ source) --
# must fall through to a from-source link. git status --porcelain catches all three.
if [ -n "$JACLLVM_PLATFORM" ] \
   && [ -z "$(git status --porcelain -- jac/native jac/build.zig jac/launcher/llvm_release.zig 2>/dev/null)" ]; then
  LLVM_VER="$(sed -nE 's/.*LLVM_VER = "([^"]+)".*/\1/p' jac/launcher/llvm_release.zig)"
  ASSET="$(scripts/jacllvm_asset_id.sh "$JACLLVM_PLATFORM" 2>/dev/null || true)"
  if [ -n "$LLVM_VER" ] && [ -n "$ASSET" ]; then
    BASE="https://github.com/jaseci-labs/jaseci/releases/download/jacllvm-v${LLVM_VER}"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    if curl -fsSL -o "$TMP/$ASSET" "$BASE/$ASSET" \
       && curl -fsSL -o "$TMP/$ASSET.sha256" "$BASE/$ASSET.sha256" \
       && ( cd "$TMP" && shasum -a 256 -c "$ASSET.sha256" >/dev/null 2>&1 ); then
      SHIM_BIN="$TMP/$ASSET"
      echo "Using prebuilt LLVMPY shim: $ASSET"
    fi
  fi
fi

# No prebuilt shim -> fetch the pinned LLVM once (idempotent; range-fetches only
# the ~84 MB subset the shim needs from the llvm-slice zip into jac/.llvm-build,
# ~0.35 GB on disk) so the -Ddev build below can compile + place the shim from it.
if [ -z "$SHIM_BIN" ]; then
  ( cd jac && zig build fetch-llvm )
fi

# Place the pinned, contained bun runtime into the source tree
# (jac/jaclang/runtimelib/client/_bun) so the -Ddev linked binary below can
# resolve it for client/cl work via get_bun(). Release binaries bundle bun into
# the payload instead; this is the editable/source-checkout equivalent.
( cd jac && zig build fetch-bun )

# Build the dev binary (needs zig 0.16.0 + network; no zstd/curl/git -- payload.zig
# does it all in std). zig build fetches the pinned typeshed stdlib stubs itself
# (the fetch-typeshed step), so there is no submodule to check out. -Ddev links the
# compiler from this checkout instead of bundling it -- fast to build, edits run live.
# On a prebuilt-shim hit above, -Dshim-bin bundles it (build.zig places it in-tree
# and skips the LLVM link); otherwise the shim is linked from the fetched LLVM.
JAC_BUILD_ARGS=(-Ddev -Dpayload-progress)
if [ -n "$SHIM_BIN" ]; then
  JAC_BUILD_ARGS+=(-Dshim-bin="$SHIM_BIN")
fi
( cd jac && zig build "${JAC_BUILD_ARGS[@]}" )

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
