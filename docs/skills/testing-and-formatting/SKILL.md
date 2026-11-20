---
name: testing-and-formatting
description: Use when writing or running tests for Jac code, reading a failing jac test run, formatting Jac source with jac fmt, or selecting and fixing lint rules in jac.toml: test blocks, jac test with -k, fmt, fmt --check, fmt --fix and [check.lint].
---
# Testing and formatting

## When to use this

Use it to add tests to Jac code, to run them and read what failed, to format what you changed, and to turn on or satisfy a project's lint rules. It assumes `writing-jac`; a project with no `jac.toml` yet starts in `starting-a-project`.

## Before you start

```sh
jac docs language/tests       # the test declaration
jac docs toolchain/test       # jac test: finding modules, -k, -o, output, statuses
jac docs toolchain/fmt        # the layout, --check, --fix
jac docs toolchain/lint       # every lint rule, and which fmt --fix applies
```

## Steps

### 1. Write test blocks

A test is a top-level declaration: `test "name" { ... }` with `assert` statements. Put tests in the module, or in its test annex `<module>.test.jac` beside it or `test/<module>.test.jac`; an annex sees the module's names without importing them. A test passes when its body ends, and fails on a failed `assert` (shown with its message) or any other exception.

```jac
"""Prices in cents, and their text."""

def cents(text: str) -> int {
    (whole, _, frac) = text.partition(".");
    return int(whole) * 100 + int((frac + "00")[:2]);
}

def label(c: int) -> str {
    return f"{c // 100}.{c % 100:02d}";
}

with entry:__main__ {
    print(label(cents("12.5")));
}

test "whole numbers" {
    assert cents("3") == 300;
}

test "rounds to two places" {
    assert cents("1.239") == 123;
}

test "label pads cents" {
    got = label(705);
    print("label was", got);
    assert got == "7.5", f"got {got}";
}

test "parse then label is the same text" {
    for t in ["0.05", "12.50"] {
        assert label(cents(t)) == t;
    }
}

test "text that is no number" {
    cents("x");
}
```

- A test is checked like the rest of the module. The module's own code (globals and plain `with entry` blocks) runs first, then the tests in source order, in one process: a global one test changes stays changed for the next.
- **A program's main code goes in `with entry:__main__`**, as above: it runs when the module is built and run as the program, and not under `jac test` or when the module is imported. Keep a plain `with entry` for setup the tests rely on.
- To test that something raises, catch it: `try { cents("x"); assert False, "no error"; } except ValueError {}`.
- A walker is tested by building a small graph in the test, spawning, and asserting on the walker's fields (`modelling-with-graphs`).

### 2. Run the tests of what you changed

```sh
jac test prices.jac             # one module; its annexes come with it
jac test prices.jac -k label    # only tests whose names contain "label"
jac test                        # the directories jac.toml's [test] lists
```

For the module above, where two tests are wrong on purpose:

```text
jac test: 1 module with tests, 1 to build, on macos-aarch64
prices.jac:27:5: FAILED[rt AssertionError]: label pads cents: got 7.05
 27 |     assert got == "7.5", f"got {got}";
    |     ^
    in module 'prices.jac'
    Traceback (most recent call last):
      File "prices.jac", line 27, in test label pads cents
        assert got == "7.5", f"got {got}";
    output:
      label was 7.05

... the second failure, ERRORED[rt ValueError]: text that is no number: invalid literal for int() with base 10: 'x', with its traceback ...
prices.jac: 3 passed, 2 failed

3 passed, 2 failed; 0 of 1 module passed in 1.19s
FAILED prices.jac::label pads cents
FAILED prices.jac::text that is no number
```

Each failure is a diagnostic at the line the test stopped at: `FAILED[rt <exception>]` for an assertion that failed, `ERRORED[rt <exception>]` for another exception, then the test's name and the message, the source line, the traceback, and after `output:` what the test printed (shown only for a failure). Each module then has one line of totals, and the last lines name every failure as `FAILED <module>::<test>`. A module whose runner does not build is listed first with its diagnostics: resolve those as in `resolving-diagnostics`.

| Exit status | Meaning |
|---|---|
| 0 | Every test passed |
| 1 | A test failed, a runner did not build, or the command line was wrong |
| 5 | No tests found, or `-k` matched none |

`jac test prices.jac -o runner` builds the runner without running it; `./runner -k label` runs it, for a debugger or another platform.

### 3. Format only the files you changed

```sh
jac fmt prices.jac impl/prices.impl.jac
jac fmt --check prices.jac      # lists files that would change, exit 1 if any
```

There are no layout options. `fmt` never changes meaning, keeps every comment, and refuses to write a file that does not parse (exit 1, with the diagnostics). Do not run it over a whole tree you did not change.

### 4. Select lint rules, and satisfy them

Lint rules are chosen in `jac.toml` and reported by `jac check` only (not by `build` or `test`). With none named they are `"clean"`: the `"style"` rules, every body in an `impl` in `impl/`, and no comment or docstring. A project names what it wants instead:

```toml
[check.lint]
select = ["style", "no-print"]
exclude = ["tests/*/reject/*"]
```

A finding names its rule in brackets:

```text
calc.jac:3:5: error[W3002]: a `has` after one with the same modifiers belongs in it: `has a: A, b: B;` [combine-has]
calc.jac:23:5: error[E3012]: print() is not allowed in this project [no-print]
```

`jac fmt --fix <files>` rewrites every finding that has a fix (every rule of the `clean` group) and every old spelling the language rejects, then formats. `no-print` and `too-many-params` need you. `jac fmt --fix --check <files>` lists what `--fix` would change, writing nothing.

## What a correct result looks like

```sh
jac check prices.jac            # quiet, status 0: types, the module's tests, lint
jac test prices.jac             # "N passed", "1 of 1 module passed", status 0
jac fmt --check prices.jac      # quiet, status 0
```

## Mistakes to expect

| Symptom | Cause | Fix |
|---|---|---|
| E0046 | A `test` inside an `obj` | Tests are top-level |
| E0013 | A `test` inside a function | Tests are top-level |
| Status 5, `no tests found` | No module under the paths has a test, or `-k` matched nothing | Name the module; check `[test] directories` |
| A test's print is missing | Output is shown only for a failing test | Assert on the value instead |
| The program's own work runs during `jac test` | Its main code is in a plain `with entry` | Move it into `with entry:__main__` |
| Lint findings in `check` but not in `test` | Selected rules are judged by `check` only | Run `jac check` |
| E3057 | A name in `select` or `ignore` that is no rule | Use a rule name from `jac docs toolchain/lint` |
| `internal error: jac fmt would change the syntax tree` | A formatter defect; the file is left as it was | Report it with the file (`resolving-diagnostics`) |
| A test annex's errors not shown by `check main.jac` | Only the main module's tests are checked | `jac check <module>.jac`, or `jac test` |

## Where to look things up

| Question | Command |
|---|---|
| The test declaration | `jac docs language/tests` |
| `jac test`, `[test]` keys | `jac docs toolchain/test`, `jac docs test.directories` |
| `assert` | `jac docs assert` |
| The layout `fmt` writes | `jac docs toolchain/fmt` |
| Every lint rule and its fix | `jac docs toolchain/lint` |
| `[check.lint]` keys | `jac docs check.lint.select` |
