---
description: The test declaration: a named block of checks at a module's top level, what it can see, how assert fails it, and where tests may be written.
keywords: test, test block, tests, unit test
grammar: test_decl
---
# Tests

A `test` block is a declaration that holds checks of the module's code. A program built from the
module leaves its tests out; `jac test` builds and runs them. This page is the declaration; the
command, its options and its output are in [test](../toolchain/test.md) (`jac docs test`).

## Syntax

```ebnf
test_decl ::= decorators "test" STRING? block
```

```jac
def double(n: int) -> int {
    return n * 2;
}

test "doubling a positive number" {
    assert double(2) == 4;
    assert double(3) == 6, "three doubled";
}

test "doubling zero" {
    assert double(0) == 0;
}
```

## What a test is

- **A test is a declaration at a module's top level**, like a function, or at the top level of the
  module's test annex (`X.test.jac` beside `X.jac`, or `test/X.test.jac`; see
  [Modules](modules.md#annexes)). It cannot be written inside a function (E0013) or an archetype
  (E0046).
- **Its name is the string after `test`**, which `jac test` reports and `-k` selects by. The name
  may be any text, and may be left out: a test without one has the empty name. Names need not be
  unique.
- **Its body is a block of statements**, run like the body of a function that takes no arguments:
  its assignments make locals of its own, and it sees the module's globals, functions and imports.
  A test annex sees the module's names without importing them.
- **A test passes when its body ends.** It fails when an exception leaves it: a failed `assert`
  (an `AssertionError`, whose message `jac test` shows), or any other exception.
- **A test is type-checked like the rest of the module** by `jac check` and `jac test`.
  `jac build`, which leaves tests out of the program, does not check them.
- A docstring may precede a test, as it may any declaration.

When `jac test` runs a module's tests, the module's code (its globals and plain `with entry`
blocks, not `with entry:__main__`) runs first, then each test in the order it is written, in one
process. A global one test changes is changed for the tests after it. Output a test prints is
shown only when it fails.

```jac
glob calls: int = 0;

def double(n: int) -> int {
    calls += 1;
    return n * 2;
}

test {
    assert double(0) == 0;
}

test "earlier tests' calls are counted" {
    x = double(5);
    assert x == 10;
    assert calls == 2, f"calls is {calls}";
}
```

```sh
jac test calls.jac
```

```text
calls.jac: 2 passed
```

## A program's main code and its tests

A program's main code belongs in `with entry:__main__` when its module has tests. The two kinds of
entry block run at different times:

| Block | Built as the program | Imported by another module | Under `jac test` |
|---|---|---|---|
| `with entry` | runs | runs | runs, before the tests |
| `with entry:__main__` | runs | does not run | does not run |

A test annex's `with entry` runs under `jac test` too, and its `with entry:__main__` never runs:
a program built from the module leaves the annex out. So keep in a plain `with entry` only the
setup the tests rely on, and put what the program does when it is run, its printing, its reading
of arguments and input and its work, in `with entry:__main__`:

```jac
glob prices: dict[str, int] = {};

with entry {
    prices["pen"] = 150;
    prices["ink"] = 400;
}

def total(items: list[str]) -> int {
    return sum([prices[i] for i in items]);
}

with entry:__main__ {
    print("total:", total(["pen", "ink", "pen"]));
}

test "a pen and ink" {
    assert total(["pen", "ink"]) == 550;
}
```

```output
total: 700
```

Built and run, the program fills `prices` and prints the total. `jac test prices.jac` fills
`prices` and runs the test, and prints nothing of the program's own:

```text
prices.jac: 1 passed
```

See [Modules](modules.md#module-code-with-entry) (`jac docs modules`) for entry blocks.

## `assert` in tests

`assert cond, message;` is the usual check in a test. The message, evaluated only when the check
fails, is what a failure report shows:

```text
prices.jac:10:5: FAILED[rt AssertionError]: cents of nothing: expected no cents
```

An `assert` is an ordinary statement, not a feature of tests: it raises the same way in any code.
See [Exceptions](exceptions.md#assert).

## What is rejected

| Code | Condition |
|---|---|
| E0013 | A `test` inside a function body, where the word is read as a name |
| E0046 | A `test` inside an archetype's body |
| E0001 | A `test` named by an identifier (`test adds_up {`): the name is a string. It is reported once, and what follows the test is read as it would be after any other |

```jac
# expect: E0046, E0001
obj Account {
    has balance: int = 0;

    test "inside the class" {
        assert Account().balance == 0;
    }
}

test adds_up {
    assert 1 + 1 == 2;
}

with entry {
    print(Account().balance);
}
```

## Differences from Python and the reference design

- A test is a language declaration, not a function found by its name, so it needs no `test_` prefix
  and no test framework. Its name is any string.
- The test blocks of the program's main module are not part of the program `jac build` makes.
- The reference design's form with a name written as an identifier, `test adds_up {`, is refused (E0001): a test's
  name is a string, `test "adds up" {`. `jac fmt --fix` does not
  rewrite the old form; change it by hand.
