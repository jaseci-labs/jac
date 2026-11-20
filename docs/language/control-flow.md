---
description: The statements that choose and repeat: if/elif/else, while, for over an iterable, the for-while-with loop, forever, switch with fallthrough, break and continue, and the else clause of a loop.
keywords: control flow, if, elif, else, while, for, for loop, while loop, forever, switch, default, fallthrough, break, continue, loop else, for else
grammar: if_stmt, elif_stmt, else_stmt, while_stmt, for_stmt, forever_stmt, switch_stmt, switch_case
---
# Control flow

`if` chooses a block by a condition, `switch` and `match` choose one by a value, and `while`, `for`
and `forever` repeat one. Every body is a block in braces; no `:` introduces it and none ends with
`;`. A condition is any expression, taken by its truth value (see
[Operators](operators.md#and-or-not)).

## `if`, `elif`, `else`

```ebnf
if_stmt ::= "comptime"? "if" expression block (elif_stmt | else_stmt)?

elif_stmt ::= "elif" expression block (elif_stmt | else_stmt)?

else_stmt ::= "else" block
```

The conditions are evaluated in order, and the block of the first one that is true runs. The
`else` block runs when none is. The condition needs no parentheses.

A test in a condition narrows a variable's type in the block it guards: after
`if v is not None`, `v` is no longer optional there. See [Types](types.md#unions).

```jac
def grade(n: int) -> str {
    if n >= 90 {
        return "A";
    } elif n >= 80 {
        return "B";
    } else {
        return "C";
    }
}

with entry {
    print(grade(95), grade(85), grade(10));
    pending: list[int] = [];
    if pending {
        print("work to do");
    } else {
        print("nothing pending");
    }
}
```

```output
A B C
nothing pending
```

`comptime if` is decided while the program compiles; see `jac docs comptime`.

## `while`

```ebnf
while_stmt ::= "while" expression block else_stmt?
```

The condition is evaluated before each pass, and the loop ends when it is false.

```jac
with entry {
    data = [1, 2, 3];
    while data {
        print(data.pop(), end=" ");
    }
    print();
}
```

```output
3 2 1 
```

## `for`

```ebnf
for_stmt ::= "comptime"? "async"? "flow"? "for" atomic_chain ("=" expression "while" expression "with" atomic_chain assignment? | "in" expression) block else_stmt?
```

The rule has two loops: `for x in iterable` and the counting loop `for x = a while c with step`.

### `for x in iterable`

The body runs once for each item of the iterable, with the target bound to the item.

- Anything iterable may follow `in`: a list, tuple, set, string (each character), dict (each key,
  in insertion order), `range(...)`, a generator, or an object with `__iter__`. Anything else is
  an error (E1021).
- The target is a name, or a parenthesized tuple of targets that unpacks each item:
  `for (k, v) in d.items()`. The parentheses are required.
- The target is a local of the enclosing function. After the loop it holds the last item. It may
  be a local declared before the loop (`d: int = 0; for d in shape`); each item is then stored as
  that local's type, so the items of an `any` are checked as they arrive (`TypeError: expected
  int, found str`).
- A list that grows while it is iterated yields the new items too. A dict or a set that changes
  size while it is iterated raises `RuntimeError`.
- A closure made in the body captures that pass's own variable; see [Functions](functions.md).

```jac
with entry {
    for ch in "ab" {
        print(ch, end=" ");
    }
    for k in {"x": 1, "y": 2} {
        print(k, end=" ");
    }
    for (i, w) in enumerate(["p", "q"]) {
        print(f"{i}:{w}", end=" ");
    }
    for n in range(10, 0, -3) {
        print(n, end=" ");
    }
    print(n);
}
```

```output
a b x y 0:p 1:q 10 7 4 1 1
```

### `for x = start while cond with step`

The counting loop of C, written with words. `x = start` runs once; `cond` is evaluated before each
pass, and the loop ends when it is false; `step`, an assignment such as `i += 2`, runs after each
pass, including one that `continue` ends.

```jac
with entry {
    acc: list[int] = [];
    for i = 0 while i < 10 with i += 3 {
        acc.append(i);
    }
    print(acc, i);
    for j = 10 while j > 0 with j //= 2 {
        if j == 5 {
            continue;
        }
        print(j, end=" ");
    }
    print();
}
```

```output
[0, 3, 6, 9] 12
10 2 1 
```

`async for` iterates an asynchronous iterator ([Async](async.md)); `flow for` runs its passes in
parallel on several threads ([Parallel loops](flow-for.md), `jac docs flow for`); `comptime for`
is unrolled while the program compiles (`jac docs comptime`).

## `forever`

```ebnf
forever_stmt ::= "forever" block
```

`forever { ... }` repeats its block until a `break`, a `return` or an exception leaves it. It is
`while True` without the condition.

```jac
with entry {
    n = 0;
    forever {
        n += 1;
        if n % 2 == 0 {
            continue;
        }
        if n > 5 {
            break;
        }
        print(n);
    }
}
```

```output
1
3
5
```

## `break` and `continue`

`break` leaves the innermost loop (or `switch`, below). `continue` ends the current pass of the
innermost loop and starts the next; in a `for ... while ... with` loop the step runs first.
`break` outside a loop or a switch, and `continue` outside a loop, are errors (E0058).

```jac
with entry {
    for i in range(3) {
        for j in range(3) {
            if j == 1 {
                break;
            }
            print(i, j);
        }
    }
}
```

```output
0 0
1 0
2 0
```

`break` is refused in a `flow for` body (E1313), whose passes run at once; `continue` is allowed
there ([Parallel loops](flow-for.md)).

## The `else` of a loop

A `while` or `for` loop may end with an `else` block. It runs when the loop ends because its
condition is false or its items are exhausted, and not when a `break` ends it. A loop that runs no
pass runs its `else`.

```jac
def find(xs: list[int], target: int) -> str {
    for x in xs {
        if x == target {
            print("found", x);
            break;
        }
    } else {
        print("no", target);
    }
    return "done";
}

with entry {
    find([1, 2, 3], 2);
    find([1, 2, 3], 9);
    find([], 1);
}
```

```output
found 2
no 9
no 1
```

## `switch`

```ebnf
switch_stmt ::= "switch" expression "{" switch_case* "}"

switch_case ::= ("case" pattern | "default") ":" stmt*
```

`switch` evaluates its subject once and runs the statements from the first `case` whose pattern
matches it. It works as C's does:

- **Execution falls through.** After the matching case's statements, those of the next case run
  too, and the next, until a `break` or the end of the switch. End a case with `break` to stop.
- **`default`** is where execution starts when no case matches, wherever it is written, and it
  falls through like any case. A switch has at most one (E0152). With no match and no default,
  nothing runs.
- **A case takes a pattern**, as `match` does: literals, `1 | 2`, `Color.RED`, `[a, b]`,
  `Point(x=0)`. A bare name is a capture pattern, which matches every value and binds it, not a
  comparison with that variable. `case _:` is the wildcard, and binds nothing: in the case's
  statements, as everywhere outside a pattern, `_` is an ordinary variable, so after `_ = 2;` a
  `print(_)` in any case prints `2`. Patterns are in [Pattern matching](pattern-matching.md). A
  case takes no `if` guard.
- `break` leaves the switch. `continue` in a switch inside a loop goes on to the loop's next pass.
- The case bodies are statements after the `:`, not blocks.

```jac
def switched(x: int) -> list[str] {
    out: list[str] = [];
    switch x {
        case 1:
            out.append("one");
        case 2:
            out.append("two");
            break;
        case 3 | 4:
            out.append("three or four");
            break;
        default:
            out.append("default");
    }
    return out;
}

with entry {
    for x in [1, 2, 3, 5] {
        print(x, switched(x));
    }
}
```

```output
1 ['one', 'two']
2 ['two']
3 ['three or four']
5 ['default']
```

`match` is the form without fallthrough, with guards; use it unless the fallthrough is wanted.

## What is rejected

| Code | Condition |
|---|---|
| E0001 | A body that is not a block: `if c: x;` or `if c x;` |
| E0032 | An `elif` or `else` that follows no `if` |
| E0058 | `break` outside a loop or a switch; `continue` outside a loop |
| E0152 | A second `default` in a switch |
| E1021 | `for x in v` where `v` cannot be iterated |
| W3024 | An `elif` whose condition repeats an earlier one of its chain, so its block never runs |
| W3025 | An `if` whose two blocks are the same |

```jac
# expect: E0058, E1021
def scan(n: int) {
    break;
    for x in n {
        print(x);
    }
}
```

```jac
# expect: E0152
def pick(n: int) {
    switch n {
        default:
            print("a");
        default:
            print("b");
    }
}
```

```jac
# expect: W3024, W3025
def sign(x: int) -> int {
    y = 0;
    if x > 0 {
        y = 1;
    } elif x > 0 {
        y = 2;
    }
    if x < 0 {
        y = -1;
    } else {
        y = -1;
    }
    return y;
}
```

The lint rules a project may select add more checks on these statements, such as an `else` after a
block that returns (W3021) and an `else` holding only an `if` (W3022); see
[Lint](../toolchain/lint.md).

## Differences from Python

- Blocks are braces; there is no `:` and no single-line body.
- `for k, v in items` is written `for (k, v) in items`.
- `forever`, `switch` and `for ... while ... with` have no Python counterpart. `switch` falls
  through; `match` does not.
- A closure made in a `for` body captures that pass's variable, where Python's closures all see the
  variable's last value.
