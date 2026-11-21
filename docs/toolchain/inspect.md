---
description: The inspect commands - jac parse for syntax errors and syntax trees, jac grammar for the grammar the parser accepts (and --page for its documentation page), and jac emit-js and emit-py for the code a space compiles to.
keywords: syntax tree, jac.spec, EBNF
---
# Inspect: parse, grammar, emit-js, emit-py

Four commands show what jac makes of source without building a program:

| Command | Shows |
|---|---|
| `jac parse` | Whether files parse, and with `--tree` their syntax trees |
| `jac grammar` | The grammar a parser accepts, in EBNF |
| `jac emit-js` | A space's JavaScript, as an app's build writes it |
| `jac emit-py` | A space's Python code, as an app's build writes it |

## parse

```sh
jac parse [--tree] <file.jac | @list>...
```

`jac parse` reads each file on its own, reports its syntax errors, and resolves nothing: not its imports, names or types (that is [check](check.md)). It prints nothing for files that parse and exits with status 0.

```sh
jac parse add.jac
```

Given a file that does not parse, it prints the diagnostics as `check` does, every one in every file, and exits with status 1:

```text
bad.jac:2:14: error[E0005]: unexpected ';'
 2 |     x = (1 + ;
   |              ^

1 error
`jac docs E0005` explains an error by its code.
```

The parser covers the whole language. A construct that parses may still be refused by `check` and `build` where jac does not implement it yet (E5090).

### --tree

`--tree` prints each file's syntax tree, one node to a line, indented under its parent. Each line is the node's `line:column`, its kind, and what it holds:

```jac
def add(a: int, b: int) -> int {
    return a + b;
}
```

```sh
jac parse --tree add.jac
```

```text
1:1 Module add.jac
  1:1 Ability def add
    1:8 FuncSig
      1:9 ParamVar a
        1:12 BuiltinType int
      1:17 ParamVar b
        1:20 BuiltinType int
      1:28 BuiltinType int
    1:32 Block
      2:5 ReturnStmt
        2:12 BinaryExpr +
          2:12 Name a
          2:16 Name b
```

The parser recovers from a syntax error, so `--tree` prints a tree for a file with errors too, after the errors.

### @list

An argument `@<file>` names a file that lists the files to parse, one to a line:

```sh
find src -name '*.jac' > files.txt
jac parse @files.txt
```

## grammar

```sh
jac grammar <parser.jac> [--page] [-o <file>]
```

`jac grammar` reads the grammar out of a parser's source and prints it as EBNF. jac's parser is `compiler/parsing/parser.jac` in jac's repository, so the command is for working on jac itself; the grammar of the jac you run is in [Grammar](../reference/grammar.md) (`jac docs reference/grammar`), and `jac docs <rule>` prints one rule.

```sh
jac grammar compiler/parsing/parser.jac
```

```text
# The Jac grammar, read out of jac's parser. Do not edit it by hand:
# `jac grammar compiler/parsing/parser.jac -o compiler/parsing/jac.spec` regenerates it, and
# tests/driver/commands.jac fails while it differs from what the parser accepts.
# Terminals in quotes are keywords and operators; UPPERCASE names are token
# classes, defined by the lexer (the lexical rules close this file).

module ::= STRING? element*

element ::=
    type_alias
    | import_stmt
    | archetype
...
```

The notation:

- `a b` is a sequence, `a | b` a choice, `a?` optional, `a*` zero or more, `a+` one or more, and parentheses group.
- Text in quotes is a terminal, a keyword or operator as written (`"if"`, `'"'`).
- An UPPERCASE name is a class of tokens (`NAME`, `STRING`), defined by the lexical rules at the end.
- A lowercase name is a rule.
- Alternatives that start with the same term have it factored out: `"for" (for_in | for_to)`.

| Option | What it does |
|---|---|
| `-o <file>` | Write it to a file instead of stdout |
| `--page` | Print it as the documentation's page of the grammar, with front matter and an introduction |

The grammar is read from three files: the parser's module, its annex `impl/<parser>.impl.jac`, and the `lexer.jac` beside it, whose keywords and operators are the lexical rules. Each rule is a method of the parser (`impl Parser.<rule>`), and the grammar starts from `Parser.module`. A file that is not such a module is refused, with what it lacks:

```text
jac: grammar: add.jac is not a parser's source: there is no impl/add.impl.jac. A parser's source is read with its annex in impl/ and the lexer.jac beside it, and its Parser.module is the rule its grammar starts from
```

`compiler/parsing/jac.spec` in jac's repository is this output, kept in the repository so that a change to the language shows in review as a change to it. It is the definition of Jac's syntax. A test fails while it differs from what the parser accepts, naming each rule that differs; after changing the parser, regenerate it:

```sh
jac grammar compiler/parsing/parser.jac -o compiler/parsing/jac.spec
jac grammar compiler/parsing/parser.jac --page -o docs/reference/grammar.md
```

## emit-js and emit-py

```sh
jac emit-js <space> -o <dir> [--app <app> [--profile <profile>]]
jac emit-py <space> -o <dir> [--app <app> [--profile <profile>]]
```

In a project with an `archwire.jac` ([Projects](projects.md)), a space whose host is not native compiles to another language: a `node`, `browser` or `hermes` space to JavaScript modules, a `cpython` space to Python code. These commands check one space's modules and write what an app's build would write for it, so you can read it, run it, or hand it to your own tools. Run them from the project's root.

<!-- example: not checked: an archwire.jac, whose spaces need the modules main.jac and jsmain.jac -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space tool: cpython { entry main; }
    space js: node { entry jsmain; }

    app tool { run tool; }
    app js { run js; }
}
```

With that `archwire.jac`, and a `main.jac` and a `jsmain.jac` that each hold a `greet` function and a `with entry` that prints `greet(...)`:

```sh
jac emit-py tool -o out-py
jac python out-py
jac emit-js js -o out-js
jac node out-js/__main.mjs
```

```text
hello, python
hello, node
```

### What emit-py writes

| In `<dir>` | What it is |
|---|---|
| `__main__.py` | The entry: `jac python <dir>` runs the space, its entry module as `__main__` |
| `py/<module>.py` | Each module as Python source, to read |
| `units/<module>.json` | Each module's Python syntax tree, which the build compiles |
| `<module>.jacpyc` | Each module's compiled code, which the runtime loads |
| `_jac.py`, `@jac/` | The space's Python runtime and its manifest |

```text
import enum
import _jac

def greet(name):
    return f'hello, {name}'

def __jac_init__():
    print(greet('python'))
__jac_init__()
```

That is `py/main.py` for the `main.jac` above.

### What emit-js writes

| In `<dir>` | What it is |
|---|---|
| `<module>.mjs` | Each module as an ES module, with a source map `<module>.mjs.map` beside it (its sources are the module's `.jac` file and its annexes) |
| `<module>.jsx` | For a space whose host renders JSX (a browser or hermes space), its modules, for the space's bundler |
| `__main.mjs` | A node space's entry, which `jac node` runs |
| `@jac/` | The JavaScript runtime the modules import (stdjac's files, and the runtime file of the space's `ui` plugin where it names one), and `bundle.json`, what the space's bundler is told |

`jac node --enable-source-maps` reports an exception's frames at the lines of the `.jac` files. A source map is version 3, its `sourceRoot` `"../"`.

- A Jac name that JavaScript reserves is written with a `$` after it: a function `undefined` is `undefined$`, and so are `catch`, `throw`, `debugger`, `globalThis`, `arguments` and `eval`. Every other name is kept as written, `Set`, `Error`, `Array` and `print` among them.
- In a `.jsx` module, another module's functions are read through its namespace: `import * as $m0 from "./helper.jsx"`.
- `@jac/bundle.json` holds `aliases`, the file each of the runtime's module names is (`@jac/runtime/lib/sys` is `@jac/lib/sys.js`, and in a hermes space `@jac/lib/sys.hermes.js`), and the space's `bundler` plugin: its name, its scripts, and the settings `jac.toml` gives it.

### --app and --profile

Without `--app`, the space's modules are written as the space alone. `--app <app>` writes the space as that app's program of it, with the app's plan (which spaces it runs, where the others are); `--profile <profile>` takes the app under the archwire's profile of that name. See [Building apps](../apps/building.md).

### What goes wrong

| Message | Cause |
|---|---|
| `` `jac emit-py` writes a space of the project in this directory, and there is no archwire.jac here `` | Not run from a project's root |
| `the archwire has no space 'web'` | The archwire declares no such space |
| `emit-js: space 'tool' runs on cpython` | `emit-js` names a cpython space; use `emit-py` |
| `emit-py: space 'js' runs on node` | `emit-py` names a JavaScript space; use `emit-js` |
| `it needs a directory to write to: -o <dir>` | No `-o` |
| `error[...]` diagnostics | The space's modules have errors. `jac check --space <space>` reports the same ([check](check.md#checking-a-project)) |

A space's modules are checked against what its host allows, so a module that builds as native code can be refused for a cpython or node space (E1540 where the host lacks what the code needs).
