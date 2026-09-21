#!/usr/bin/env bash
# Mutation tests: both required invalidation and reuse, in a disposable repo.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
git init -q
git config user.name 'Cache test'
git config user.email 'cache-test@example.invalid'
mkdir -p scripts jac/jaclang/compiler jac/jaclang/scale jac/bootstrap/python jac/native
cp "$repo/scripts/ci_cache_keys.sh" scripts/
cp "$repo/jac/jaclang/compiler_inputs.txt" jac/jaclang/
printf 'compiler\n' > jac/jaclang/compiler/pass.jac
printf 'app\n' > jac/jaclang/scale/app.jac
printf 'recipe\n' > jac/bootstrap/python/build.sh
printf 'bridge\n' > jac/bootstrap/python/compiler_bridge.c
printf 'shim\n' > jac/native/shim.cpp
printf 'dependencies\n' > jac/build.zig.zon
git add .
git commit -qm seed
keys() { bash scripts/ci_cache_keys.sh; }
key() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }
same() { [ "$(key "$before" "$1")" = "$(key "$after" "$1")" ] || { echo "Unexpected invalidation: $1" >&2; exit 1; }; }
changed() { [ "$(key "$before" "$1")" != "$(key "$after" "$1")" ] || { echo "Missed invalidation: $1" >&2; exit 1; }; }
commit() { git add .; git commit -qm "$1"; }

before=$(keys)
# Build outputs present at save time must not change any checkout fingerprint.
mkdir -p jac/jaclang/vendor/typeshed/stdlib jac/jaclang/compiler/__pycache__
printf generated > jac/jaclang/vendor/typeshed/stdlib/generated.pyi
printf generated > jac/jaclang/compiler/libjacllvm.so
printf generated > jac/jaclang/compiler/__pycache__/generated.pyc
after=$(keys)
[ "$before" = "$after" ]
rm -rf jac/jaclang/vendor jac/jaclang/compiler/__pycache__ jac/jaclang/compiler/libjacllvm.so

printf 'app edit\n' >> jac/jaclang/scale/app.jac
commit app
after=$(keys)
same compiler; same python_cpython; same python_jacpython
changed payload; changed binary

before=$after
mkdir -p jac/jaclang/compiler/tests
printf fixture > jac/jaclang/compiler/tests/fixture.jac
printf test > jac/jaclang/compiler/pass.test.jac
commit tests
after=$(keys)
same compiler; same python_cpython; same python_jacpython

before=$after
printf 'compiler edit\n' >> jac/jaclang/compiler/pass.jac
commit compiler
after=$(keys)
changed compiler; changed python_jacpython; changed binary; same python_cpython

before=$after
git mv jac/jaclang/compiler/pass.jac jac/jaclang/compiler/renamed.jac
commit rename
after=$(keys)
changed compiler; changed python_jacpython

before=$after
git rm -q jac/jaclang/compiler/renamed.jac
commit delete
after=$(keys)
changed compiler; changed python_jacpython

before=$after
printf adapter >> jac/bootstrap/python/compiler_bridge.c
commit adapter
after=$(keys)
same compiler; same python_cpython; changed python_jacpython; changed binary

before=$after
printf recipe >> jac/bootstrap/python/build.sh
commit recipe
after=$(keys)
changed python_cpython; changed python_jacpython; same compiler

before=$after
printf dependency >> jac/build.zig.zon
commit dependency
after=$(keys)
changed binary; changed python_jacpython; same python_cpython

before=$after
printf shim >> jac/native/shim.cpp
commit shim
after=$(keys)
changed binary; changed python_jacpython; same python_cpython
before=$after
mkdir -p jac/examples/tiny_jacyac
printf example > jac/examples/tiny_jacyac/web.jac
commit tiny-example
after=$(keys)
changed binary; same compiler; same python_cpython; same python_jacpython
echo 'CI cache mutation tests passed'
