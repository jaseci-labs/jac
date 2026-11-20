---
description: jac lsp, the language server an editor runs - setting an editor up, which program a file is checked in, what the server answers (diagnostics, navigation, hover, completion, rename, formatting, code actions), its settings and commands, and jac query for the same answers from the command line.
keywords: language server, LSP, editor, IDE, go to definition, find references, hover, completion, rename, code action, quick fix, semantic tokens, inlay hints, jac query, jac.lint, jac.index
---
# lsp and query

`jac lsp` is a language server: an editor starts it and speaks the [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) to it on stdin and stdout. It checks the programs the open files belong to as they are edited, with what is unsaved, and answers the editor from what the checks found. Nothing it answers is worked out apart from the compiler: a diagnostic is what `jac check` reports, and a definition is what the checker resolved the name to.

`jac query` asks the same questions from the command line ([below](#query)).

## Setting an editor up

The server takes no argument and no option. Any editor with a Language Server Protocol client runs it as `jac lsp` for files ending in `.jac`, with the project's directory as the workspace folder.

Neovim (0.11 or later):

```lua
vim.filetype.add({ extension = { jac = "jac" } })
vim.lsp.config("jac", {
  cmd = { "jac", "lsp" },
  filetypes = { "jac" },
  root_markers = { "jac.toml", "archwire.jac", ".git" },
})
vim.lsp.enable("jac")
```

Helix (`languages.toml`):

```toml
[language-server.jac]
command = "jac"
args = ["lsp"]

[[language]]
name = "jac"
scope = "source.jac"
file-types = ["jac"]
roots = ["jac.toml", "archwire.jac"]
language-servers = ["jac"]
```

Emacs (eglot):

```text
(add-to-list 'eglot-server-programs '(jac-mode . ("jac" "lsp")))
```

VS Code runs a language server through an extension. A minimal one passes `{ command: "jac", args: ["lsp"] }` as the server options of `vscode-languageclient`, with `{ scheme: "file", language: "jac" }` as its document selector.

The server writes nothing but the protocol on stdout. What a tool it runs prints (a C compiler, cargo) goes to stderr.

## Which program a file is checked in

A Jac file is checked as part of a program, and the server picks the program:

| The file | Its program |
|---|---|
| A module | The largest program the server knows that holds it; otherwise the module as its own program, as `jac check <module>` checks it |
| An impl annex (`impl/x.impl.jac`) or a test annex (`x.test.jac`) | Its module's. A test annex is checked with its module as the main module, so its tests are checked |
| A module of a project whose `archwire.jac` declares spaces | The program of the space that places it, on that space's host (as `jac check --space <space>`) |
| A target variant (`x.windows.jac`) | The variant as the main module of its own program, checked for its target (as `jac check --target`) |
| `archwire.jac` | A program it governs |

When nothing else is asked of it, the server checks every program of the workspace folders once: each main module nothing else reaches, leaving out what `jac.toml`'s `[check] exclude` leaves out, and each space of an archwire that declares spaces. It keeps each program's diagnostics and a table of its references, and lets the program go. That index is what makes references, rename and workspace symbols reach files that are not open, and what tells the server that `core/clock.jac` belongs to the program of `main.jac`.

- **A check gives way to typing.** A check is abandoned when a newer edit arrives, and starts again once the edits pause (150 ms by default).
- **A check keeps going past errors.** `jac check` stops at the first phase that finds errors; the server reports every phase's, so a syntax error in one file does not hide a type error in another. Inside a statement the parser had to skip, only the syntax error is reported.
- **A check runs what a build's check runs.** A program with C or Rust modules has them compiled the first time, from the [build cache](cache.md) afterwards.
- **At most four checked programs are kept** in memory, the least recently used let go first.

## What it answers

| Request | Answer |
|---|---|
| Diagnostics, pushed or pulled, for a document and for the workspace | Every error and warning of every phase, in every file of a checked program, with its code linked to its page of the reference |
| Definition | Where the name is defined: for a declaration with an `impl`, the `impl` |
| Declaration | The declaration itself: the `def` in the module |
| Implementation | A function's `impl`; the overrides below a method; the subclasses of a class; for a walker, `spawn` or `visit`, the abilities that fire; for a node or an edge, the abilities it triggers |
| Type definition | The class of what is at the cursor |
| References, document highlights | Every use, in every program of the workspace |
| Document symbols, workspace symbols | A file's outline; the declarations of every program |
| Call hierarchy, type hierarchy | Callers and callees; supertypes and subtypes |
| Hover | The kind, the signature or type, a constant's value, the docstring and what a `sem` says; for a keyword or operator, its page of the documentation; for any other expression, its type |
| Signature help | The function or class being called, and the parameter the cursor is at |
| Completion | After `.`: the members of the receiver's type, a module's names, a class's statics and enum members. Elsewhere: the locals in scope, the module's names, the builtins, and the keywords the grammar takes there. After two letters, what other modules declare: accepting one adds its wire or its import |
| Rename | Every use, in every program; a method is renamed with its overrides |
| Formatting | The document, a range, or the statement just typed, as `jac fmt` lays it out |
| Semantic tokens | What each name is: a class, a parameter, a field, a method, a module, and whether it is declared, written or the library's |
| Inlay hints | The type of a local bound without one; the parameter a positional argument is bound to |
| Folding and selection ranges | The brackets, comment runs, strings and imports; each enclosing piece of syntax |
| Document links | An import's module |
| Code lens | `Run test` over a `test`, `Run` over `with entry` |
| Renaming a file | A module renamed where it is has its imports, its wires and rules in `archwire.jac`, and its annexes and tests renamed with it |

A name from a C module, a Rust module, a Python package or an npm package resolves to the interface jac made of it, not to the header or the source it was read from.

### Architecture

The server answers one request that is not the protocol's own, `jac/architecture`, and says so in its capabilities: `experimental.architectureProvider` is `true`. It is what [`jac arch`](arch.md) draws, for the document an editor is in.

| Parameter | Meaning |
|---|---|
| `textDocument.uri` | The document. A module's file asks for that module; `archwire.jac` for its project |
| `position.line` | In `archwire.jac`, the line of a `layer` asks for that layer, opened. Not needed otherwise |
| `view` | `layers` (the default) or `spaces` |
| `profile` | With `spaces`, the profile that arranges them |

The answer is `null` for a file no `archwire.jac` governs, and otherwise an object:

| Member | Holds |
|---|---|
| `picture` | What `jac arch --json` prints: the boxes, the arrows with their wires, and the wiring's errors |
| `svg` | The picture, as `jac arch --svg` writes it. Each box is a `<g>` with a `data-id` and each arrow one with a `data-key`, so a panel can tell what was clicked |

It is drawn from the text the editor holds, saved or not, so a panel that asks again after each edit follows the project.

### Code actions

| For | Action |
|---|---|
| An unknown name (W2001) | Wire it from the module that declares it, into the wire `archwire.jac` already has for that provider and consumer or a new one in the block they share; where no archwire governs the module, import it |
| A crossing no edge rule admits (E2099) | Add the rule the message names |
| An import written in a governed module (E1144, E2094) | Move it into `archwire.jac` |
| A name a wire binds and nothing uses (E1146) | Remove it from the wire |
| A lint diagnostic, or `source.fixAll` | Apply what `jac fmt --fix` does to the module and its annexes |
| A declaration with no `impl` | Write the `impl` into the module's annex |
| The leading imports, or `source.organizeImports` | Put them in order |

## Settings

The server reads the `jac` section of the editor's settings, through `workspace/configuration` and `workspace/didChangeConfiguration`, and the same keys from `initializationOptions`:

| Key | Default | Meaning |
|---|---|---|
| `lint` | `true` | Check the lint rules `jac.toml` selects |
| `index` | `true` | Check the programs of the workspace that are not open |
| `programs` | `4` | How many checked programs are kept in memory |
| `settle` | `150` | Milliseconds without an edit before a check starts |

## Commands

`workspace/executeCommand` runs:

| Command | Arguments | Does |
|---|---|---|
| `jac.test` | The file | `jac test <file>` in the workspace folder, in the background; its output is logged and its result shown when it ends |
| `jac.run` | The file | `jac run <file>`, the same way |
| `jac.bring` | The file, a name, the module that declares it | Wires or imports the name, through `workspace/applyEdit` |

## query

```sh
jac query <what> <file>[:<line>[:<column>]]
```

`jac query` checks the file as the server does, in the program it belongs to, and prints one answer. Lines and columns count from 1. It is for scripts and for agents that have no editor.

| `<what>` | Prints |
|---|---|
| `definition`, `declaration`, `implementation`, `type`, `references` | Places, one to a line: `<file>:<line>:<column>-<line>:<column>` |
| `hover` | What hover shows, as Markdown |
| `symbols` | The file's outline |
| `completion` | What completion offers there, a label and its detail to a line |
| `signature` | The signature being called and the parameter at the cursor |
| `diagnostics` | The diagnostics of the file's program |
| `arch` | The JSON of the architecture picture the document is in ([arch](arch.md)): a module's file gives its module, the line of a `layer` in `archwire.jac` that layer, anywhere else there the project |

```sh
jac query definition main.jac:12:9
jac query references core/clock.jac:3:5
jac query symbols main.jac
```
