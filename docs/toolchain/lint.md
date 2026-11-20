---
description: The lint rules a project selects in jac.toml's [check.lint], every rule by name with what it reports and whether jac fmt --fix applies it, and the spellings and probable mistakes jac always rejects.
keywords: lint, lint rules, combine-has, combine-glob, simplify-ternary, unnecessary-else-after-return, nested-if-to-elif, simplify-return-bool, unnecessary-none-return, too-many-params, no-print, strip-comments, strip-docstrings, separate-impls, impls-in-annex, precommit
---
# Lint rules

jac holds source to rules of three kinds:

| Kind | Reported | Configured |
|---|---|---|
| [Spellings the language rejects](#spellings-jac-always-rejects): where Jac had two ways to write one thing, jac accepts one | By `check`, `build` and `test`, always | No |
| [Probable mistakes](#probable-mistakes): code that cannot be what was meant | By `check`, `build` and `test`, always | No |
| [Selected rules](#the-rules): style and policy, `"clean"` unless a project chooses otherwise | By `check` only, and only when selected | `jac.toml`'s `[check.lint]` |

Every finding is an error with a code, like any other diagnostic ([check](check.md)). [`jac fmt --fix`](#fmt---fix) rewrites most of them.

**A project is held to `"clean"` unless it selects other rules, and that is intended.** Jac source
carries no comments and no docstrings, and a module reads as its declarations, with every body in
an `impl` in its annex. What a comment would say goes in the commit message, when it is why the
code is as it is, and in the project's README or docs, when it is what a reader must know; a
docstring's content goes in the README or docs too. `jac fmt --fix` applies all of it: it
deletes the comments and docstrings and moves the bodies. A project that wants other rules says so
in `[check.lint]` ([below](#selecting-rules)).

## Selecting rules

```toml
[check.lint]
select = ["style", "separate-impls"]   # rules by name, and the groups "style" and "clean"
ignore = ["combine-glob"]              # taken out of what select chose
exclude = ["tests/*/reject/*"]         # files left alone
```

| Key | Type | Default | Meaning |
|---|---|---|---|
| `select` | list of strings | `["clean"]` | The rules to report: rule names, `"style"` for the style rules, and `"clean"` for every rule but `no-print` and `too-many-params` |
| `ignore` | list of strings | `[]` | Rules taken out of what `select` chose. Names and groups, as in `select` |
| `exclude` | list of strings | `[]` | fnmatch patterns of file paths, relative to the project's root, that no selected rule judges |

- **A project that names no rules gets `"clean"`**: one with no `select`, with no `[check.lint]`, and a file in no project. `select = []` selects none.
- A rule that is not selected is never reported.
- `jac check` reports each selected rule as an error, at the code it judges: a finding in a body written in an annex is at the annex's line (`impl/simplify_ternary.impl.jac:2:13`), not at the declaration. `jac build` and `jac test` do not judge selected rules.
- Rules are selected by name, not by code. A name in `select` or `ignore` that is no rule is error E3057, at its place in `jac.toml`.
- **Under `"clean"`, `jac fmt --fix` deletes every comment and docstring** of the files the rules judge, since `strip-comments` and `strip-docstrings` are among them, and moves every body into its module's annex. That is so in a project that names no rules. `exclude` names the files to leave alone, and `ignore` the rules to leave out: `ignore = ["strip-comments", "strip-docstrings"]` keeps them.

```text
jac.toml:5:22: error[E3057]: [check.lint] select names 'no-such-rule', which is no rule a project selects
 5 | select = ["style", "no-such-rule"]
   |                      ^

1 error
`jac docs E3057` explains an error by its code.
```

## The rules

| Rule | Code | Reports | Group | `fmt --fix` |
|---|---|---|---|---|
| `combine-has` | W3002 | A `has` right after one with the same modifiers, which it belongs in | `style`, `clean` | yes |
| `combine-glob` | W3003 | The same of a `glob` | `style`, `clean` | yes |
| `simplify-ternary` | W3008 | `a if a else b`, which is `a or b` | `style`, `clean` | yes |
| `unnecessary-else-after-return` | W3021 | An `else` after a body that ends in `return` or `raise` | `style`, `clean` | yes |
| `nested-if-to-elif` | W3022 | An `else` holding only an `if` | `style`, `clean` | yes |
| `simplify-return-bool` | W3023 | An `if` whose branches return `True` and `False` | `style`, `clean` | yes |
| `unnecessary-none-return` | W3037 | `-> None` on a function that returns no value | `style`, `clean` | yes |
| `too-many-params` | W3030 | A signature with more than 7 parameters | none | no |
| `no-print` | E3012 | A call of the builtin `print` | none | no |
| `strip-comments` | W3050 | Every comment | `clean` | yes: deletes it |
| `strip-docstrings` | W3051 | Every docstring, and every string written as a statement | `clean` | yes: deletes it |
| `separate-impls` | W3055 | A body written inline that an `impl` could hold | `clean` | yes: moves it |
| `impls-in-annex` | W3056 | An `impl` in its module, or an annex beside its module instead of in `impl/` | `clean` | yes: moves it |

`style` is the style rules. `clean` is `style` and the policies for a project's layout and its comments: no comment, no docstring, every body in an `impl` in its module's annex. `fmt --fix` applies each rule of both, so selecting either never leaves work the fixer cannot do. The two rules in no group need their author, and are selected by name: `select = ["clean", "no-print", "too-many-params"]` is every rule.

jac's own `jac.toml` names no rules, so its compiler and its toolchain's build are held to `"clean"`: their source holds no comment or docstring and every body is in an annex. It names only the files the rules leave alone:

```toml
[check.lint]
exclude = ["rt/*", "tests/*", "examples/*", "scripts/*"]
```

### The style group, in one program

This program compiles and runs. Under `select = ["style"]`, `jac check` reports seven findings in it:

```jac
glob width: int = 1;
glob height: int = 2;

obj Point {
    has x: int = 0;
    has y: int = 0;
}

def pick(a: int, b: int) -> int {
    return a if a else b;
}

def sign(n: int) -> int {
    if n < 0 {
        return -1;
    } else {
        return 1;
    }
}

def grade(score: int) -> str {
    if score > 90 {
        print("high");
    } else {
        if score > 50 {
            print("middle");
        }
    }
    return str(score);
}

def positive(n: int) -> bool {
    if n > 0 {
        return True;
    } else {
        return False;
    }
}

def log(msg: str) -> None {
    print(msg);
}

with entry {
    log(grade(pick(0, 95) + sign(3) + width + height + Point().y));
    print(positive(1));
}
```

```output
high
99
True
```

```text
style.jac:2:1: error[W3003]: a `glob` after one with the same modifiers belongs in it: `glob a = 1, b = 2;` [combine-glob]
style.jac:6:5: error[W3002]: a `has` after one with the same modifiers belongs in it: `has a: A, b: B;` [combine-has]
style.jac:10:12: error[W3008]: 'a if a else b' is 'a or b' [simplify-ternary]
style.jac:16:7: error[W3021]: the `else` after a body that ends in `return` is unnecessary [unnecessary-else-after-return]
style.jac:24:7: error[W3022]: an `else` holding only an `if` is an `elif` [nested-if-to-elif]
style.jac:33:5: error[W3023]: an `if` whose branches return True and False returns its condition [simplify-return-bool]
style.jac:40:22: error[W3037]: '-> None' on 'log' is unnecessary: a function that declares no return type returns None [unnecessary-none-return]
7 errors
`jac docs W3003` explains an error by its code.
```

(Each diagnostic also shows its source line; they are left out here.) The message of a selected rule ends with the rule's name in brackets. `jac fmt --fix style.jac` rewrites the file to:

```jac
glob width: int = 1,
     height: int = 2;

obj Point {
    has x: int = 0,
        y: int = 0;
}

def pick(a: int, b: int) -> int {
    return a or b;
}

def sign(n: int) -> int {
    if n < 0 {
        return -1;
    }
    return 1;
}

def grade(score: int) -> str {
    if score > 90 {
        print("high");
    } elif score > 50 {
        print("middle");
    }
    return str(score);
}

def positive(n: int) -> bool {
    return n > 0;
}

def log(msg: str) {
    print(msg);
}

with entry {
    log(grade(pick(0, 95) + sign(3) + width + height + Point().y));
    print(positive(1));
}
```

```output
high
99
True
```

### What each rule judges

| Rule | Detail |
|---|---|
| `combine-has`, `combine-glob` | A statement joins the one directly before it when both have the same modifiers (access tag, `static`), neither has a docstring and neither has accessors. A comment between them does not keep them apart. A blank line does: it starts a group of its own, which stays one |
| `simplify-ternary` | Only where writing `a` twice runs nothing twice: `a` is a name, a chain of plain attributes from a name (`b.v`), or a literal. `f() if f() else b` is left alone |
| `unnecessary-else-after-return` | The final `else` of a plain `if`. An `if`/`elif` chain is left alone |
| `nested-if-to-elif` | After an `if` or at the end of an `elif` chain. A loop's `else` is not one |
| `simplify-return-bool` | An `if` with one `else`, each branch a single `return` of `True` or `False`. Reported instead of `unnecessary-else-after-return`, which would also fit |
| `unnecessary-none-return` | Functions, methods and lambdas, in a declaration whose `impl` holds the body too. A body with `return None;` says it differently and is left alone; a nested function's `return` is its own |
| `too-many-params` | Functions and lambdas; `self` is not counted. A function declared in `import from c { ... }` has the signature its library gives it and is not judged |
| `no-print` | Only the builtin. A method named `print`, or a local bound to the name, is something else |
| `strip-docstrings` | A module's, a global's, an archetype's, a field's, an enum's and a test's docstring |
| `separate-impls` | A function's, a method's and an ability's body. An accessor's body stays with its property, and a nested function's with the function around it. A `by` function (`def f(...) -> T by e;`) has no body to move: the one it runs is the compiler's |
| `impls-in-annex` | An `impl` written in a module's own file, and an annex file `<module>.impl.jac` sitting beside its module instead of in `impl/` |

### Layout policies

`separate-impls` and `impls-in-annex` together keep every body out of a module's own file: the module declares, and `impl/<module>.impl.jac` implements. `fmt --fix` moves each body, with the comments inside it, into that annex, creating it when it is not there. See [Projects](projects.md#impl-annexes) for where annexes go.

## Spellings jac always rejects

These are errors in every program, with no configuration. `fmt --fix` rewrites every one of them.

| Written | Write | Code |
|---|---|---|
| `def __init__`, `def __post_init__` | `def init`, `def postinit` | W3004 |
| `def f()`, `lambda () ...`, `obj A()`, `enum E()` | No parentheses when there is nothing in them | W3005 |
| `import from __future__ { annotations }` | Nothing | W3009 |
| An `impl` that restates its declaration's signature differently | The declaration's signature | W3010 |
| A `;` standing for nothing (stray, after accessors, after a for step) | No `;` | W3013 |
| `@staticmethod` | `static def` | W3001 |
| `@property` | `has x: T { getter { ... } }` | W3043 |
| `hasattr(x, "a") and x.a ...`, where `x`'s class has `a` | `x is not None and ...` | W3007 |
| `getattr(x, "a", None)`, where `x`'s class has `a` | `x?.a` | W3039 |
| `case (a, b):` | `case [a, b]:` | E0155 |
| `sem x is "..."` | `sem x = "...";` | E0156 |
| A backtick on a name that needs none, as on the attribute in ``obj.`type`` | The bare name | E0157 |
| `async static def` | `static async def`. Modifiers come in the order `comptime override static\|class async def` | E0158 |
| `def f -> int { e }`: a body's last expression as its value | `return e;` | E0159 |
| A block's last expression statement without `;` | With `;` | E2084 |
| `lambda (x: int) { x * 3; }`: a lambda of one expression that only computes a value | `lambda (x: int) { x * 3 }` | E0160 |
| `x = (yield v);`, `(yield v);`, `f"{(yield v)}"` | `x = yield v;`, `yield v;`, `f"{yield v}"` | E0161 |
| `R"..."`, `B"..."`, `br"..."` | `r"..."`, `b"..."`, `rb"..."` | E0162 |
| `0XFF`, `0B1`, `0O7`, `1E3` | `0xFF`, `0b1`, `0o7`, `1e3` | E0163 |
| `visit x`, `sem x = "..."` or an item of a `graph {}` block, without `;` | With `;` | E0002 |
| An enum member, the last included, or a filter's type (`[?:T x == 1]`), without `,` | With `,` | E0002 |

```jac
# expect: W3009, W3005 x5, W3013
import from __future__ { annotations }

obj Account() {
    has owner: str = "",
        balance: int = 0;

    def __post_init__() {
        self.balance += 0;
    }

    @staticmethod
    def bank() -> str {
        return "First";
    }

    @property
    def rich() -> bool {
        return self.balance > 100;
    }
}

with entry {
    a = Account(owner="ada", balance=200);
    print(a.owner, Account.bank(), a.rich);
    f = lambda () -> int { return 1; };
    print(f());;
}
```

Seven are reported at once, because they are all found while the file is read. The rest of this file's old spellings (`__post_init__`, `@staticmethod`, `@property`) are judged in a later phase and would be reported once these are gone ([check](check.md#the-order-errors-are-reported-in)). One run of `jac fmt --fix` rewrites all ten:

```jac
obj Account {
    has owner: str = "",
        balance: int = 0;

    def postinit {
        self.balance += 0;
    }

    static def bank -> str {
        return "First";
    }

    has rich: bool {
        getter {
            return self.balance > 100;
        }
    }
}

with entry {
    a = Account(owner="ada", balance=200);
    print(a.owner, Account.bank(), a.rich);
    f = lambda -> int { return 1; };
    print(f());
}
```

```output
ada First True
1
```

A function also has one body. An `impl` of a function that was written with its own body is E2016, and a second `impl` of one function is E2017. Neither has a fix.

## Probable mistakes

Where the reference design warns about a likely mistake, jac refuses it, each where it cannot be anything else:

| Written | Why it is refused | Code |
|---|---|---|
| `x is 1`, `x is not "a"` | `is` compares identity. Compare a value with a literal with `==` or `!=` | W3035 |
| An `if`/`elif` chain repeating a condition that only reads | Nothing run between the two could change its answer, so the second branch never runs | W3024 |
| An `if` whose branches are the same | The condition decides nothing | W3025 |
| The same name on both sides of a filter's comparison: `tasks[?:Task, owner == owner]` | The left name is the item's field and the right one is the name in scope, a mistake whichever was meant | W3040 |

```jac
# expect: W3035, W3024, W3025
def f(x: int) -> int {
    if x is 1 {
        return 1;
    } elif x > 2 {
        return 2;
    } elif x > 2 {
        return 3;
    }
    if x > 0 {
        return 5;
    } else {
        return 5;
    }
}

with entry {
    print(f(1));
}
```

These have no fix: what was meant is the author's to say.

## fmt --fix

```sh
jac fmt --fix .            # rewrite, then format
jac fmt --fix --check .    # list what would change; write nothing
```

`jac fmt --fix <path>...` rewrites what can be rewritten, then formats ([fmt](fmt.md)):

- every old spelling in the table above, whatever the project selects;
- of the rules the file's project selects, all but `too-many-params` and `no-print`.

How it works:

- A module and its annexes are fixed together. A body or an `impl` moves into `impl/<module>.impl.jac` with the comments inside it.
- Nothing is written until every file the run would write parses. A file that does not parse is reported and nothing of its module is changed.
- An `impl` whose signature differs from its declaration's gets the declaration's signature, when both name the same parameters. One naming other parameters is left for its author.
- The `hasattr` and `getattr` fixes (W3007, W3039) depend on types, so they are made only once the program has no other errors: run `fmt --fix` again after the first run has cleared the rest.
- The probable mistakes are never rewritten.

After `--fix`, run `jac check` to see what is left for you.

## `jac precommit`

```sh
jac precommit                 # fix, format and check the staged .jac files
jac precommit --verify        # change nothing: fail when a file is not as the fixer leaves it
jac precommit --all           # the whole project in place of the staged files
jac precommit --install       # git's hooks, once in a clone
```

`jac precommit` is `fmt --fix` and `check` together, for a commit:

- It runs `jac fmt --fix` on the `.jac` files staged (a module with its annexes), then checks each module as `jac check` does, under the rules its project selects.
- It exits with status 1 when a check fails, when `--verify` finds a file to fix, or when it rewrote a staged file, which is then to stage again.
- `--verify` refuses a staged file that has changes that are not staged: what would be committed is not what is on disk.
- `--install` writes git's `pre-commit` hook, which runs `jac precommit --verify`, and a `commit-msg` hook that refuses a commit naming an AI as its author. A hook jac did not install is kept unless `--force`, which saves it as a `.bak` file.

A module is checked as a program of its own. One that is no program is fixed and not checked, and precommit says how many:

| Not checked | Why | What checks it |
|---|---|---|
| Another target's variant (`host.windows.jac` on Linux) | The check is of this machine's target | `jac check <main.jac> --target <platform>` |
| A file `jac.toml`'s `[check] exclude` names | The project says so: a fixture that must fail, say | The project's tests |

A file of a project whose `archwire.jac` declares spaces is checked in its project, whose apps are its programs: precommit runs `jac check` there once, however many of its files are staged ([Checking a project](check.md#checking-a-project)).

`[check] exclude` is read from the `jac.toml` of the project precommit runs in, and from the file's own project where that is another:

```toml
[check]
exclude = ["tests/*"]   # fnmatch patterns of file paths, relative to the project's root
```

jac's own names `rt/*` and `tests/*`: the runtime's modules are parts of programs (its internal ones are refused as a program, E5153), and the suites check the tests' programs.

## Which files the rules judge

Selected rules judge the project's own modules as their author wrote them:

- modules under the project's root (the directory of the `jac.toml`), but not what `[check.lint] exclude` names;
- not the runtime's modules, which belong to the toolchain;
- not the modules of a library or a plugin the project declares, which are their package's own wherever its directory is: one installed in the project's `eco/jac/`, or one declared by a directory inside the project's tree;
- not code the compiler writes into a module.

A program outside any project (no `jac.toml` at or above its main module) has no selected rules.
