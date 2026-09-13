#!/usr/bin/env bash
# CI runs from a committed checkout. Git identities exclude restored/generated
# files and are identical in setup-jac and the dev/release build workflows.
set -euo pipefail

fingerprint() {
    git ls-tree -r HEAD -- "$@" | git hash-object --stdin
}

echo "binary=$(fingerprint jac.toml jac/examples/jaclang_org jac/jaclang jac/build.zig jac/build.zig.zon jac/launcher jac/bootstrap jac/native jac/sitecustomize.py jac/_jac_finder.py)"
echo "package=$(fingerprint jac/jaclang)"
echo "python=$(fingerprint jac/bootstrap jac/jaclang jac/build.zig jac/build.zig.zon jac/native)"
echo "layers=$(fingerprint jac/launcher jac/bootstrap jac/build.zig jac/build.zig.zon jac/native jac/jaclang/dist/payload jac/jaclang/client/bun_installer.jac jac/jaclang/compiler/backends/native/wasm_rt)"

# Same conservative producer boundary as compiler_source_files in driver/jir.
# This scopes portable cache restores; each product still validates its actual
# compiler/source/dependency identities when it is consumed.
compiler_sources="$(git ls-tree -r HEAD -- \
    jac/jaclang/jac0.py \
    jac/jaclang/bootstrap_manifest.py \
    jac/jaclang/meta_importer.py \
    jac/jaclang/jac0core \
    jac/jaclang/compiler \
    jac/jaclang/runtime \
    jac/jaclang/lib \
    jac/jaclang/cli/cli_boot.jac \
    jac/jaclang/project/tomlio.jac \
    jac/jaclang/dist/precompile_bytecode.jac \
    | grep -E '\.(jac|py)$' \
    | grep -vE '(^|/)(tests|test)/|\.test\.jac$')"
if [ -z "$compiler_sources" ]; then
    echo 'Compiler input set is empty' >&2
    exit 1
fi
compiler_key="$(printf '%s\n' "$compiler_sources" | git hash-object --stdin)"
echo "compiler=${compiler_key:0:16}"
