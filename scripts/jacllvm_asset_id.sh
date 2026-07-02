#!/usr/bin/env bash
# Deterministic content id + filename for the prebuilt LLVMPY_* shim -- the single
# source of that identity, so the producer (release-jacllvm.yml) and consumer
# (fresh_env.sh) can never disagree. The id is keyed on the shim's inputs
# (native/**, build.zig, llvm_release.zig, via their git object hashes) AND the
# per-platform release target below (the glibc floor the shim is pinned to), so a
# floor/triple bump mints a new asset even when the sources are unchanged. Both
# sides also read the target from here (--build-target), so the value the shim is
# built with and the value folded into its id can never drift apart.
#
# Run from the repo root against committed state (HEAD); callers with possible
# uncommitted shim edits (fresh_env) must gate on a clean worktree first.
#
# Usage: scripts/jacllvm_asset_id.sh <platform>                  # -> asset filename
#        scripts/jacllvm_asset_id.sh <platform> --build-target   # -> zig -Dtarget value
#        platform in { linux-x86_64, linux-aarch64, macos-aarch64 }
set -euo pipefail

platform="${1:?usage: jacllvm_asset_id.sh <platform> [--build-target]}"

# Canonical release target (glibc floor) per platform. Folded into the id so the
# identity tracks the ABI floor, and emitted via --build-target so the producer
# builds -Dtarget with the exact value the id was computed from. macOS pins its
# floor via the SDK, not a zig triple, so its target is empty.
case "$platform" in
  linux-x86_64)  target="x86_64-linux-gnu.2.17";  ext=so ;;
  linux-aarch64) target="aarch64-linux-gnu.2.17"; ext=so ;;
  macos-aarch64) target="";                       ext=dylib ;;
  *) echo "jacllvm_asset_id.sh: unknown platform '$platform'" >&2; exit 2 ;;
esac

if [ "${2:-}" = "--build-target" ]; then
  printf '%s\n' "$target"
  exit 0
fi

_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum
  else
    shasum -a 256
  fi
}

id="$(
  { git rev-parse "HEAD:jac/native" "HEAD:jac/build.zig" "HEAD:jac/launcher/llvm_release.zig"
    printf 'target=%s\n' "$target"; } \
    | _sha256 | cut -c1-16
)"

printf 'libjacllvm-%s-%s.%s\n' "$platform" "$id" "$ext"
