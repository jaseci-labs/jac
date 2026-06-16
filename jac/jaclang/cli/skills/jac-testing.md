---
name: jac-testing
description: Writing and running tests in Jac - `test "name" { }` blocks, `jac test` flags, testing walkers via spawn + .reports, the persisted-root/`jac clean` gotcha, file-naming rules, parametrize(), JacTestClient for in-process endpoint tests, [test] config. Load before writing any test or when a test run behaves strangely. Pair with `jac-debugging` (diagnosing failures) and `jac-by-llm` (MockLLM).
---

Tests are first-class language blocks written alongside the code they test - `jac run` ignores them; `jac test` runs them. All checks are plain `assert` statements, with an optional message: `assert user.is_valid(), f"bad user: {user.name}";`.

```jac
obj User {
    has name: str, email: str;

    def is_valid() -> bool { return "@" in self.email; }
}

test "user is valid" {
    user = User(name="Alice", email="alice@example.com");
    assert user.is_valid();
}
```

## Running tests

```
jac test main.jac                 # all tests in a file
jac test                          # all tests in current directory
jac test -d tests/                # all tests in a directory
jac test main.jac -t "my test"    # one test by name (quote multi-word names)
jac test -d tests/ -f "user*"     # filter test FILES by Unix pattern
jac test main.jac -x              # stop on first failure
jac test main.jac -m 3            # stop after 3 failures
jac test main.jac -v              # verbose (one line per test)
```

A `test "some name"` block becomes unittest case `test_some_name` (spaces -> underscores). Defaults live in the `[test]` section of jac.toml (`directory`, `filter`, `verbose`, `fail_fast`, `max_failures`).

## File naming - two traps

- **Never name files `test_*.jac`** (e.g. `test_utils.jac`) - the `test_` prefix collides with Python's test-module import machinery. Use `utils_tests.jac`, or the annex form below.
- **`<mod>.test.jac` is an ANNEX, not a standalone file.** Like `.impl.jac`, it attaches to a same-basename module: `people.test.jac` pairs with `people.jac`, and you run `jac test people.jac`. A `.test.jac` with no base module fails with `No module named '<mod>'`. The annex sees the module's declarations without imports - ideal for keeping tests out of the main file.

## Graph state: tests share a persisted root

Verified behavior: tests in a file run **in declaration order against one shared `root`**, and anything hung off `root` also **persists to `.jac/data` between runs**. Two consequences:

- A later test sees nodes created by an earlier test in the same run.
- A green suite can go red on re-run because last run's nodes are still there - or crash with `NodeAnchor <id> is not a valid reference` when stale persisted anchors meet recompiled code.

Fix both the same way: `jac clean --all --force` (or `jac clean --data`) before the run. Write graph assertions defensively - count nodes you just created (or filter by a unique field) rather than asserting totals on `root`.

## Testing walkers: spawn + `.reports`

```jac
node Person { has name: str; has age: int; }

walker FindAdults {
    can check with Root entry {
        for p in [-->][?:Person] {
            if p.age >= 18 { report p; }
        }
    }
}

test "finds adults only" {
    root ++> Person(name="Alice", age=30);
    root ++> Person(name="Bob", age=15);
    result = root spawn FindAdults();
    assert len(result.reports) == 1;
    assert result.reports[0].name == "Alice";
}
```

The spawn expression returns the walker instance; every `report` it made is in `result.reports` (a list, in report order). Assert graph shape directly too: `assert len([root-->]) == 2;`, `assert alice in [root ->:Friend:->];`.

## Expecting an exception

No `pytest.raises` - use try/except with a guard assert:

```jac
test "divide by zero raises" {
    try {
        divide(10, 0);
        assert False, "should have raised";
    } except ZeroDivisionError {
        assert True;
    }
}
```

## Parameterized tests

`parametrize()` registers one test per input, in a `with entry` block:

```jac
import from jaclang.runtimelib.test { parametrize }

def _test_square(pair: tuple) {
    assert pair[0] ** 2 == pair[1];
}

with entry {
    parametrize("square", [(2, 4), (3, 9), (0, 0)], _test_square);
}
```

Each case runs and reports independently (`square_0`, `square_1`, ...); pass `id_fn=` to name cases from their parameter.

## In-process endpoint tests: JacTestClient

For testing served endpoints (`walker:pub` / `def:pub`) without starting a real server, use the Python-side client from pytest:

```python
from jaclang.runtimelib.testing import JacTestClient

def test_task_crud(tmp_path):
    client = JacTestClient.from_file("app.jac", base_path=str(tmp_path))
    client.register_user("testuser", "password123")            # auth in one line
    resp = client.post("/walker/CreateTask", json={"title": "My Task"})
    assert resp.ok and resp.status_code == 200
    assert len(client.post("/walker/GetTasks").json()["reports"]) == 1
    client.close()
```

`base_path=tmp_path` keeps each test's persisted graph isolated. Also available: `get/put/request`, `login`, `set_auth_token`, `resp.data` (unwrapped envelope), `client.reload()` (HMR).

## Pitfalls

- **`-f` filters test FILES (Unix glob on filenames), `-t` selects one test by name.** They are not interchangeable. `-t` without a filepath/directory is an error.
- **LLM-powered functions**: don't hit a real model in tests - use `MockLLM` with canned outputs (see `jac-by-llm`).

## See also

- `jac-debugging` - the check/fix loop, stale-cache triage (`jac clean` vs `jac purge`)
- `jac-config` - `[test]` defaults, `[scripts]` (`test = "jac test -v"`)
- `jac-walker-patterns` - report/reports semantics being asserted here
