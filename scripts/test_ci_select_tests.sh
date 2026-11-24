#!/usr/bin/env bash
# Mutation tests for ci_select_tests.sh, in a disposable repo.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
git init -q
git config user.name 'Select test'
git config user.email 'select-test@example.invalid'
mkdir -p scripts jac/jaclang/compiler/tests/fixtures jac/tests/native/fixtures release_notes
cp "$repo/scripts/ci_select_tests.sh" scripts/
printf 'pass\n' > jac/jaclang/compiler/pass.jac
printf 'helper prim_alpha\n' > jac/jaclang/compiler/tests/cases.jac
printf 'uses cases\n' > jac/jaclang/compiler/tests/test_equiv.jac
printf 'other\n' > jac/jaclang/compiler/tests/test_other.jac
printf 'fixture\n' > jac/jaclang/compiler/tests/fixtures/prim_alpha.jac
printf 'compile "loop_shape"\n' > jac/tests/native/test_loops.jac
printf 'unrelated\n' > jac/tests/native/test_misc.jac
printf 'fixture\n' > jac/tests/native/fixtures/loop_shape.jac
printf 'fixture\n' > jac/tests/native/fixtures/orphan_case.jac
printf 'graph import {\n    a ++> b;\n    tests.x ++> test_loops;\n}\n' > jac/jaclang/archwire.jac
git add .
git commit -qm seed

sel() { bash scripts/ci_select_tests.sh scope HEAD~1 HEAD; }
expect() {
  local got
  got=$(sel)
  [ "$got" = "$1" ] || { printf 'case %s\nexpected:\n%s\ngot:\n%s\n' "$2" "$1" "$got" >&2; exit 1; }
}
commit() { git add -A; git commit -qm "$1"; }

printf 'edit\n' >> jac/tests/native/test_loops.jac
commit test-edit
expect $'scope=tests\njac/tests/native/test_loops.jac' "a test file selects itself"

printf 'note\n' > release_notes/1.md
printf 'edit\n' >> jac/tests/native/test_misc.jac
commit note-and-test
expect $'scope=tests\njac/tests/native/test_misc.jac' "release notes are ignored"

printf 'edit\n' >> jac/tests/native/fixtures/loop_shape.jac
commit fixture
expect $'scope=tests\njac/tests/native/test_loops.jac' "a fixture selects the tests naming it"

printf 'edit\n' >> jac/tests/native/fixtures/orphan_case.jac
commit orphan
expect $'scope=tests\njac/tests/native/test_loops.jac\njac/tests/native/test_misc.jac' "an unnamed fixture selects its whole test tree"

printf 'edit\n' >> jac/jaclang/compiler/tests/fixtures/prim_alpha.jac
commit helper-fixture
expect $'scope=tests\njac/jaclang/compiler/tests/test_equiv.jac\njac/jaclang/compiler/tests/test_other.jac' "a fixture named by a helper selects the helper's tree"

git rm -q jac/tests/native/test_misc.jac
commit delete
expect 'scope=tests' "a deleted test selects nothing"

sed -i 's/tests.x ++> test_loops;/tests.x ++> test_loops | test_more;/' jac/jaclang/archwire.jac
printf 'new\n' > jac/tests/native/test_more.jac
commit archwire-test
expect $'scope=tests\njac/tests/native/test_more.jac' "archwire wiring for tests stays test-scoped"

sed -i 's/a ++> b;/a ++> c;/' jac/jaclang/archwire.jac
commit archwire-source
expect 'scope=full' "archwire wiring for source modules is full"

printf 'edit\n' >> jac/jaclang/compiler/tests/cases.jac
commit helper
expect 'scope=full' "a test helper is full"

printf 'edit\n' >> jac/jaclang/compiler/pass.jac
commit source
expect 'scope=full' "a source file is full"

mkdir -p jac/jaclang/testing jac/examples/app
printf 'runner\n' > jac/jaclang/testing/test_runner.jac
commit runner-source
expect 'scope=full' "a test_ name outside a tests tree is source"

printf 'app test\n' > jac/examples/app/test_app.jac
commit example-test
expect 'scope=full' "an example's test is not owned by a lane"

mkdir -p .github/workflows
printf 'on: push\n' > .github/workflows/ci.yml
commit ci-config
expect 'scope=full' "anything outside the test tree is full"

echo 'CI test selection mutation tests passed'
