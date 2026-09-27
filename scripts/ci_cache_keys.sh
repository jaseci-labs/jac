#!/usr/bin/env bash
# CI fingerprints describe the checked-out commit, never generated/restored files.
# Run once immediately after checkout; reuse these outputs for restore AND save.
# This is intentionally not a local incremental-build key (which must read edits).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

compiler_paths=(jac/jaclang/compiler_inputs.txt)
while IFS= read -r entry || [ -n "$entry" ]; do
  case "$entry" in ''|'#'*|'!'*) continue ;; esac
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
# The compiler-input RULE lives twice on purpose: here in awk, and in
# jir.compiler_source_files. They cannot be merged -- this script runs at
# checkout time, before any jac binary exists (the same acyclicity constraint as
# the Zig seeds, #8785) -- so they are held to the same answer by
# jac/tests/compiler/test_compiler_identity_rule.jac instead. This mode is what
# that test reads; it prints package-relative paths, one per line.
if [ "${1:-}" = "--list-compiler-inputs" ]; then
  compiler_tree | awk -F '\t' '{print $2}' | sed 's|^jac/jaclang/||' | LC_ALL=C sort -u
  exit 0
fi

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
  jac/examples/tiny_jacyac \
  jac.toml jac/jac.toml | emit binary
tree jac/launcher jac/bootstrap jac/build.zig jac/build.zig.zon jac/native \
  jac/jaclang/client/bun_installer.jac jac/jaclang/compiler/backends/native/wasm_rt |
  emit layers
# The kernel's stage-0 compiler as the committed pin names it: a pinned commit,
# or "self" when this checkout's compiler builds its own kernel (also when the
# pin is absent). Read from HEAD like every key above, never the work tree.
stage0_pin=$(git show HEAD:jac/bootstrap/stage0.json 2>/dev/null || true)
stage0=$(printf '%s' "$stage0_pin" | tr -d ' \t\r\n' |
  sed -n 's/.*"commit":"\([0-9a-f]\{40,64\}\)".*/\1/p')
printf 'stage0=%s\n' "${stage0:-self}"
