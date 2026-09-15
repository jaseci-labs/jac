#!/usr/bin/env bash
# CI fingerprints describe the checked-out commit, never generated/restored files.
# Run once immediately after checkout; reuse these outputs for restore AND save.
# This is intentionally not a local incremental-build key (which must read edits).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

compiler_paths=(jac/jaclang/compiler_inputs.txt)
while IFS= read -r entry || [ -n "$entry" ]; do
  case "$entry" in ''|'#'*) continue ;; esac
  compiler_paths+=("jac/jaclang/$entry")
done < jac/jaclang/compiler_inputs.txt

tree() { git ls-tree -r HEAD -- "$@"; }
compiler_tree() {
  tree "${compiler_paths[@]}" |
    awk -F '\t' '$2 ~ /\.(jac|py)$/ || $2 == "jac/jaclang/compiler_inputs.txt"' |
    awk -F '\t' '$2 !~ /\/(tests|test|__pycache__)\// && $2 !~ /\/\.[^\/]+\// && $2 !~ /\.test\./'
}
python_tree() {
  tree jac/bootstrap/build_python.zig jac/bootstrap/seed.zig jac/bootstrap/python |
    if [ "$1" = cpython ]; then
      # Matches build_python.buildKey's host-mode exclusions. Jac sources and
      # native bridge edits cannot invalidate the ordinary CPython SDK.
      awk -F '\t' '$2 !~ /\/(compiler-bridge.patch|compiler_bridge.c|compiler_bridge.h|prepare_native.py|compiler_runtime.c|object_api.c|binding_api.c)$/'
    else
      cat
    fi
}
fingerprint() {
  # Sort/deduplicate overlapping roots; paths and modes accompany blob hashes.
  LC_ALL=C sort -u | git hash-object --stdin
}
emit() {
  local digest
  digest=$(fingerprint)
  printf '%s=%s\n' "$1" "$digest"
}

compiler_tree | emit compiler
python_tree cpython | emit python_cpython
{
  python_tree jacpython
  compiler_tree
  tree jac/jaclang/vendor/typeshed/PIN jac/jaclang/vendor/typeshed/TARBALL_SHA256 \
    jac/native jac/build.zig jac/build.zig.zon jac/bootstrap/pins.json
} | emit python_jacpython
tree jac/jaclang | emit payload
tree jac/jaclang jac/build.zig jac/build.zig.zon jac/launcher jac/bootstrap \
  jac/native jac/_jac_finder.py jac/sitecustomize.py jac/examples/jaclang_org \
  jac.toml jac/jac.toml | emit binary
tree jac/launcher jac/bootstrap jac/build.zig jac/build.zig.zon jac/native \
  jac/jaclang/client/bun_installer.jac jac/jaclang/compiler/backends/native/wasm_rt |
  emit layers
