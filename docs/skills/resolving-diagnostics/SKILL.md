---
name: resolving-diagnostics
description: Use when jac check, build or test reports an error such as error[E1452] or error[W2001], or a built program stops with a traceback: how to read the diagnostic, look its code up, fix errors in the right order, and tell a mistake in your code from a defect in jac.
---
# Resolving jac diagnostics

## When to use this

Use it when `jac check`, `jac build` or `jac test` prints `error[...]`, when a built program ends with a traceback, or when jac itself fails. It assumes the loop of `writing-jac`. Errors from the lint rules a project selects are covered in more depth by `testing-and-formatting`, and errors from moving the reference design code by `porting-from-the-reference-design`.

## Before you start

Run the narrowest command that shows the error, on the main module that imports the file you changed:

```sh
jac check main.jac
```

`check` reports what a build would, plus the main module's own tests and the project's lint rules. It writes to stderr and exits 1 when there is any error.

## Steps

### 1. Read each diagnostic

Its parts:

```text
c3.jac:6:9: error[E1030]: Cart has no field 'totl'
 6 |     t = c.totl;
   |         ^^^^^^

1 error
`jac docs E1030` explains an error by its code.
```

`file:line:column` (from 1), the code, the message, the source line marked with `^` from where the mistake's place starts to where it ends. A `warning[CODE]` is shown the same way and fails nothing. A lint finding ends with the rule's name in brackets, `[combine-has]`. An error inside a generic function's copy carries a line `in positive[-1], asked for at main.jac:7:11` naming the call that made the copy.

### 2. Look the code up

`jac docs E1030` prints the message's template, what it means, a program that raises it and the fix. A code means one condition everywhere, so the entry applies whatever the message's details.

### 3. Fix the first error first

jac checks in phases (syntax, declarations, types and ownership, lint) and reports a later phase only once the earlier ones are clean. Within syntax, one mistake can produce several errors after it, and the parser notices a mistake where the next token is, often on the line after it:

```jac
# expect: E0002 x3
def label(n: int) -> str {
    if n > 0 {
        return "pos";
    }
    return "neg"
}

with entry {
    x = label(1);
    print(x
}
```

This reports `missing ';'` at the `}` that closes `label` (the `;` belongs after `return "neg"`, on the line before), then `missing ','` and `missing '}'` at the end of the file, which are both consequences of the one missing `)` after `print(x`. Fix the first error, run `check` again, and repeat. Once syntax is clean, fix each type error in order; one cause rarely produces two type errors.

### 4. Expect some codes in pairs

These are one mistake reported at two places:

| Pair | Fix at |
|---|---|
| E1229 at a call, with the error inside the copy it asked for (E0109, E1001, ...) | The call's arguments |
| E1284 at a bounded generic's declaration, with E1030 or E1110 at the use | The bound or the body |
| E2093 on `archwire.jac`, with that file's syntax errors | `archwire.jac` |

```jac
# expect: E1229, E0109
def positive[comptime N: int](x: int) -> int {
    comptime assert N > 0, "N is positive";
    return x * N;
}

with entry {
    print(positive[-1](3));
}
```

### 5. A spelling jac rejects is fixed by the formatter

W3001, W3004, W3005, W3007, W3009, W3013, W3039, W3043, E0155 to E0163 and E2084 each name an old spelling (`@staticmethod`, `def __init__`, `def f()`, `case (a, b):`, `sem x is`, `def f -> int { e }`, `lambda (x: int) { x * 3; }`, ...), and so does a missing `;` after `visit x` or a missing `,` after an enum's last member. Run `jac fmt --fix <file>`, then `check` again. The table "Spellings jac always rejects" in `jac docs toolchain/lint` lists them. Fix W3010 (an impl whose signature differs from its declaration) by hand, copying the declaration's signature into the impl, before you run `fmt --fix` on that file.

### 6. A lint finding

(`[rule-name]` at the end) comes from a rule the project selected in `jac.toml`. Most have a fix: `jac fmt --fix <file>`. `jac docs toolchain/lint` says which.

### 7. An error whose location is not your code

Read the whole report first:
- A location inside a generic's body with an `asked for at` line is your call's fault: fix the call.
- A location inside jac's runtime or a library module, with an error of yours in the same report: fix yours, and the other usually goes.
- Only errors in jac's own files, for code that follows the documentation: treat it as a defect (step 9).

### 8. A traceback when the program runs

is an exception nothing caught. It goes to stderr and the exit status is 1:

```text
Traceback (most recent call last):
  File "t1.jac", line 6, in <module>
    print(price("ink"));
  File "t1.jac", line 2, in price
    return {"pen": 2}[item];
KeyError: 'ink'
```

The last line is the exception; the frames above it go from the outermost call to where it was raised, each with its source line when the program can read the file from where it runs. `jac docs library/exceptions` lists the builtin exceptions. An `OverflowError: integer overflow` means an `int` passed 64 bits.

### 9. When it is jac's defect

Signs: `internal error` in jac's output, a crash or a segmentation fault of jac or of a built program, a program that checks but does not build, an error that contradicts the documentation's own example, or a wrong result. Then:
- reduce it to the smallest whole program that still shows it;
- report it with that program, the command, and what jac printed;
- do not rewrite working code to dodge it, and do not leave a workaround in the code without saying so.

## What a correct result looks like

`jac check main.jac` prints nothing and exits 0 (on a terminal, one line `✓ Checked main.jac in 0.21s`). Then the build and the tests pass as in `writing-jac`.

## Mistakes to expect

| Mistake | What happens | Do instead |
|---|---|---|
| Fixing errors from the bottom of the report | Consequences of the first error are fixed by hand and come back | Fix the first, re-run |
| Treating a `W` code as a warning | The build still fails: every diagnostic is an error | Fix it like any other |
| Searching the message's text | Details vary; the code does not | `jac docs <code>` |
| Reading E5090 as a mistake in the code | It names something jac does not build yet | Use the form the entry suggests |
| Expecting `check main.jac` to check an imported module's tests | Only the main module's tests are checked | `jac check other.jac`, or `jac test other.jac` |
| Reading the line of a syntax error literally | The mistake is often at the end of the line before | Look at the token before the `^` |

## Where to look things up

| Question | Command |
|---|---|
| One code's meaning and fix | `jac docs <code>` |
| The diagnostic format, phases, code ranges | `jac docs toolchain/check` |
| Every code, by range | `jac docs section diagnostics` |
| Rejected spellings and lint rules | `jac docs toolchain/lint` |
| What `fmt --fix` rewrites | `jac docs toolchain/fmt` |
| Exceptions at run time | `jac docs library/exceptions` |
