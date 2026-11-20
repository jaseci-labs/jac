---
description: jac fmt, the one layout Jac source is written in, what it keeps and what it changes, --check, --fix, and the [fmt] exclude patterns of jac.toml.
keywords: formatter, formatting
---
# fmt

`jac fmt` rewrites Jac source in one canonical layout. There are no options that change the layout: every Jac file formatted by jac looks the same.

```sh
jac fmt src main.jac     # rewrite main.jac and every .jac file under src/
jac fmt --check .        # change nothing; list what would change, exit 1 if any
jac fmt --fix .          # first rewrite what has a fix, then format
```

Formatting changes how a file is spaced and broken into lines, never what it means. Before writing a file, `fmt` parses what it is about to write and stops with an internal error unless that is the same syntax tree with the same comments in the same order.

## An example

Before:

<!-- example: not checked: unformatted on purpose, the input to jac fmt -->
```jac
import os;
# A point on a grid.
obj Point { has x: int = 0, y: int = 0;
  def dist(other: Point) -> int { return abs(self.x - other.x) + abs(self.y - other.y); } }



def describe(first_point: Point, second_point: Point, label: str, separator: str, suffix: str) -> str {
    return label + separator + str(first_point.dist(second_point)) + separator + str(second_point.dist(first_point)) + suffix; # both ways
}
with entry { a = Point(x=1,y=2); b = Point(x=4,y=6)
;print(describe(a, b, "distance", ": ", "."));
    names = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda_", "mu"];
    if len(names) > 3 and names[0] == "alpha" and names[1] == "beta" and names[2] == "gamma" and names[3] == "delta" { print(& a is not None); }
}
```

After `jac fmt`:

```jac
import os;

# A point on a grid.
obj Point {
    has x: int = 0,
        y: int = 0;

    def dist(other: Point) -> int {
        return abs(self.x - other.x) + abs(self.y - other.y);
    }
}

def describe(
    first_point: Point, second_point: Point, label: str, separator: str, suffix: str
) -> str {
    return label
        + separator
        + str(first_point.dist(second_point))
        + separator
        + str(second_point.dist(first_point))
        + suffix;  # both ways
}

with entry {
    a = Point(x=1, y=2);
    b = Point(x=4, y=6);
    print(describe(a, b, "distance", ": ", "."));
    names = [
        "alpha",
        "beta",
        "gamma",
        "delta",
        "epsilon",
        "zeta",
        "eta",
        "theta",
        "iota",
        "kappa",
        "lambda_",
        "mu",
    ];
    if len(names) > 3
        and names[0] == "alpha"
        and names[1] == "beta"
        and names[2] == "gamma"
        and names[3] == "delta"
    {
        print(&a is not None);
    }
}
```

```output
distance: 7: 7.
True
```

## The layout

| Rule | |
|---|---|
| Line width | At most 100 columns |
| Indentation | Four spaces |
| A group of brackets (a list, a call's arguments, parameters) | On one line when it fits. Otherwise one item to a line, with a trailing comma |
| A list of numbers that does not fit | Packed several to a line, with a trailing comma |
| A call's arguments or a signature's parameters | First tried together on a line of their own, as `describe`'s parameters are above, before one to a line |
| A chain of operators | On one line when it fits. Otherwise one operand to a line, each line starting with its operator |
| A block's `{` | At the end of its line; on a line of its own after a condition that had to break, as the `if` above |
| Several fields in one `has`, several globals in one `glob` | One to a line, aligned |
| Blank lines between statements | Kept, one at most |
| Declarations with bodies | Set apart by a blank line |
| String literals | Keep their spelling: quotes, prefixes and escapes are not rewritten |
| Parentheses | Those the author wrote are kept: `(a)`, `(-x) ** 2` |
| A lambda of one simple statement | Stays on one line when it fits |
| A `match` or `switch` case | Its statements on indented lines under it |
| JSX text | Kept as written |

### Comments

Comments stay where they were written, in order. None is dropped or moved past code.

- A comment on a line of its own stays on a line of its own, at the indentation of the code it precedes.
- A comment after code stays at the end of that code's line, two spaces after it.
- A comment after an opening bracket stays on the bracket's line, and the last comments inside brackets stay inside them.
- A block comment, `#* ... *#`, written before code on its line stays before it.

### Spacing is the formatter's

How code is spaced changes nothing it means, so `fmt` decides all of it:

- A prefix `&` is a borrow however it is spaced. `& x` and `&x` are the same, and `fmt` writes `&x`. `&(x)` is the same borrow too; `fmt` keeps its parentheses, as it keeps any the author wrote.
- A `<` compares wherever a value is before it, the `}` of a set or dict among them: `{1} <s` is the comparison `{1} < s`, and `fmt` writes it so. A `<` starts a JSX element only where an expression can start, written against the element's name.
- The arrows are tokens of their own. `a<--b` holds the arrow `<--`; `a < --b` compares `a` with `--b`.

## Which files

Each path is a file or a directory.

- A **file** is formatted, whatever its project's `jac.toml` says.
- A **directory** means every `.jac` file under it, except files and directories whose names start with `.`, and except what the project's `[fmt] exclude` names.

```toml
[fmt]
exclude = ["build/*", "*/reject/*"]
```

`exclude` is a list of fnmatch patterns. Each is matched against a file's or directory's path relative to the project's root, with `/` between its parts. The project's root is the nearest directory, at or above the directory given, that holds a `jac.toml`. A directory that matches is not entered. Use it for generated code and for programs that are meant to fail to compile.

## A file that does not parse

`fmt` formats only files that parse. One that does not is reported, with the diagnostics a build would give for it, and left exactly as it is; the other files are still formatted, and the exit status is 1.

A file that parses with a warning (W0060, a string that documents nothing) is left as it is too: the tree has no place for the string, so printing the tree would lose it. The warning is shown and fails nothing. `fmt --fix` deletes the string and formats the file.

```text
gen/broken.jac:2:14: error[E0005]: unexpected ';'
 2 |     x = (1 + ;
   |              ^

1 error
`jac docs E0005` explains an error by its code.
```

## --check

`--check` writes nothing. It prints the path of each file that would change, one to a line, on stdout, and exits with status 1 if there is any. It is the form for CI:

```sh
jac fmt --check .
```

```text
./src/messy.jac
```

## --fix

`--fix` rewrites what has a mechanical fix, then formats:

- every old spelling the language rejects (`def f()` with empty parentheses, `def __init__`, `@staticmethod`, a stray `;`, and the rest), always;
- each lint rule the file's project selects in `jac.toml`'s `[check.lint]` that has a fix;
- in an `archwire.jac`, the [declared wires](../language/modules-wiring.md#declared-wires---) of the project's files in other languages, mended to what each file's source writes as its own language reads it: a wire is written for an import no wire declares (E1575), and a wire or a name of one that no source writes is removed (E1147). It changes no `++>` wire and no source file.

A module and its annexes are fixed together, because some fixes move code between them. Nothing is written unless every file the run would write parses. `--fix --check` lists the files `--fix` would change and writes none.

[Lint rules](lint.md) (`jac docs toolchain/lint`) lists every rule, which have fixes, and what each fix writes.

## Exit statuses

| Status | Meaning |
|---|---|
| 0 | Every file is formatted (or, without `--check`, was rewritten) |
| 1 | A file does not parse; or, with `--check`, a file would change; or the command line was wrong |

`fmt` prints nothing when it has nothing to report.

## What goes wrong

| Message | Cause |
|---|---|
| `it needs the files or directories to format` | No path was given. `fmt` does not read standard input |
| `<path>: no such file or directory` | The path is neither a file nor a directory |
| `[fmt] exclude must be a list of strings` | `exclude` has another type |
| `internal error: jac fmt would change the syntax tree of <file>` | A defect in the formatter. The file is not written; report it with the file |
