#!/usr/bin/env bash
# Mutation tests for ci_plan.sh, in a disposable repo.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
git init -q
git config user.name 'Select test'
git config user.email 'select-test@example.invalid'
mkdir -p scripts jac/jaclang/compiler/tests/fixtures jac/tests/native/fixtures release_notes
cp "$repo/scripts/ci_plan.sh" scripts/
printf 'pass\n' > jac/jaclang/compiler/pass.jac
printf 'helper prim_alpha\n' > jac/jaclang/compiler/tests/cases.jac
printf 'uses cases\n' > jac/jaclang/compiler/tests/test_equiv.jac
printf 'other\n' > jac/jaclang/compiler/tests/test_other.jac
printf 'fixture\n' > jac/jaclang/compiler/tests/fixtures/prim_alpha.jac
printf 'compile "loop_shape"\n' > jac/tests/native/test_loops.jac
printf 'unrelated\n' > jac/tests/native/test_misc.jac
printf 'fixture\n' > jac/tests/native/fixtures/loop_shape.jac
printf 'fixture\n' > jac/tests/native/fixtures/orphan_case.jac
cat > jac/jaclang/archwire.jac <<'WIRE'
graph import {
    pass ++> commands.analysis.test { warn };
    cases ++> test_equiv { helper };
    runtime.JacTest.jac_test { check };
}
WIRE
git add .
git commit -qm seed

sel() { bash scripts/ci_plan.sh scope HEAD~1 HEAD; }
expect() {
  local got
  got=$(sel)
  [ "$got" = "$1" ] || { printf 'case %s\nexpected:\n%s\ngot:\n%s\n' "$2" "$1" "$got" >&2; exit 1; }
}
commit() { git add -A; git commit -qm "$1"; }
subst() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }

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

subst 's/cases ++> test_equiv { helper };/cases ++> test_equiv | test_other { helper };/' jac/jaclang/archwire.jac
commit archwire-test
expect $'scope=tests\njac/jaclang/compiler/tests/test_equiv.jac\njac/jaclang/compiler/tests/test_other.jac' "test wiring selects the wired tests and the helper's tree"

subst 's/commands.analysis.test { warn }/commands.analysis.test { warn, more }/' jac/jaclang/archwire.jac
commit archwire-source
expect 'scope=full' "a source module named test is full"

subst 's/runtime.JacTest.jac_test { check }/runtime.JacTest.jac_test { check, more }/' jac/jaclang/archwire.jac
commit archwire-jac-test
expect 'scope=full' "a source module ending in _test is full"

git mv jac/jaclang/compiler/pass.jac jac/tests/native/test_pass.jac
commit move-source
expect 'scope=full' "moving source into a tests tree is full"

git rm -q jac/tests/native/test_misc.jac
commit delete
expect 'scope=tests' "a deleted test selects nothing"

printf 'edit\n' >> jac/jaclang/compiler/tests/cases.jac
commit helper
expect 'scope=full' "a test helper is full"

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

printf 'site\n' > README.md
commit readme
expect 'scope=tests' "a path no lane reads selects nothing"

# The plan: lanes from a catalog, owned files, test-only narrowing.
mkdir -p .github/ci
cat > .github/ci/lanes.json <<'LANES'
{
  "test_roots": ["tests", "jaclang/compiler/tests"],
  "excluded": {},
  "deps": {"web": ["a>=1,<2"]},
  "lanes": [
    {"name": "native", "paths": ["tests/native"], "jobs": "4", "zig": true},
    {"name": "equiv", "paths": ["jaclang/compiler/tests"], "deps": ["web"]}
  ]
}
LANES
commit catalog
lanes_of() { python3 -c 'import json,sys; print(" ".join("%s:%d" % (l["name"], l["count"]) for l in json.loads(sys.stdin.read())))'; }
got=$(bash scripts/ci_plan.sh plan .github/ci/lanes.json | lanes_of)
[ "$got" = "native:2 equiv:2" ] || { echo "full plan: got '$got'" >&2; exit 1; }

printf 'edit\n' >> jac/tests/native/test_loops.jac
commit plan-test-only
got=$(bash scripts/ci_plan.sh plan .github/ci/lanes.json HEAD~1 HEAD | lanes_of)
[ "$got" = "native:1" ] || { echo "test-only plan: got '$got'" >&2; exit 1; }

mkdir -p jac/tests/orphan
printf 'x\n' > jac/tests/orphan/test_lost.jac
commit orphan-test
if bash scripts/ci_plan.sh plan .github/ci/lanes.json >/dev/null 2>&1; then
  echo "a test in no lane must fail the plan" >&2; exit 1
fi
git rm -q jac/tests/orphan/test_lost.jac
commit drop-orphan

sed 's|"paths": \["jaclang/compiler/tests"\]|"paths": ["jaclang/compiler/tests", "tests/native/test_loops.jac"]|' .github/ci/lanes.json > lanes.tmp
mv lanes.tmp .github/ci/lanes.json
commit double-owner
if bash scripts/ci_plan.sh plan .github/ci/lanes.json >/dev/null 2>&1; then
  echo "a test in two lanes must fail the plan" >&2; exit 1
fi

echo 'CI plan mutation tests passed'
