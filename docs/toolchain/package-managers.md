---
description: What jac reads and checks of a project's Jac packages, for whoever writes a package manager - where an installed package goes, the record beside it, what a package's jac.toml says, versions and requirements, how jac.lock pins every installed package and its digest, jac packages --json, the tools' table of jac.toml, and the format numbers this contract changes by.
keywords: package manager, writing a package manager, installed packages contract, record format, lock format, jac packages, interface_ver, tool table
---
# Writing a package manager

jac has no package manager. It reads a project's Jac packages from one directory, checks what
it finds there against what the project asks for, and pins it. A package manager is a program of
its own that fills that directory: it chooses versions, fetches them, publishes them, and keeps
whatever registry, names and accounts it has. This page is everything jac asks of such a
program and everything it gives one. [Packages](packages.md) says the same from a project's side.

| jac's | A package manager's |
|---|---|
| What a package is, and what its `jac.toml` says | Where versions of a package are published |
| What a version and a requirement are | Which version satisfies every package that asks |
| Where an installed package is, and its record | Fetching a package, and putting it there |
| Checking what is installed against what was asked | Names, and who owns one |
| `jac.lock`, and its digest | Publishing, withdrawing, mirrors |
| `jac packages`, which says what is missing | Its own settings and its own cache |

jac never starts a package manager. A user runs one, and then `jac install`.

## A package

A package is a directory with a `jac.toml` at its top and its modules beside it. Its `[project]`
says what it is:

```toml
[project]
name = "postgres"
kind = "plugin"
version = "0.4.1"
jac = "0.4"

[plugin]
fills = "store"
interface_ver = 1
class = "postgres.store.PostgresStore"

[packages]
rows = "1.2"
```

| Key | Meaning |
|---|---|
| `project.name` | The package's name: an identifier, the name it is installed under, and for a library the name modules import |
| `project.kind` | `"library"`, which modules import, or `"plugin"`, which a project binds and nothing imports |
| `project.version` | Its version, `MAJOR.MINOR.PATCH` as [Semantic Versioning](https://semver.org) has it. Required of a package that is asked for by version |
| `project.jac` | The oldest jac it builds with. A least version and no more |
| `plugin.fills` | For a plugin, the abstraction it fills ([Plugins](../apps/plugins.md)) |
| `plugin.interface_ver` | For a plugin, the version of that abstraction's interface it was written for |
| `packages.<name>` | Each package it uses: a version requirement, or a place |

A library's and a plugin's `[packages]` name libraries only. Only a project declares a plugin.

## Versions and requirements

- **A requirement is the least version asked for:** `"1"`, `"1.2"` or `"1.2.3"`. It is satisfied
  by that version and every later one in which its left-most number that is not zero is
  unchanged: `"1.2"` below 2.0.0, `"0.4"` below 0.5.0, `"0.0.3"` by 0.0.3 alone.
- **There is no other form.** No range, no exact version, no exclusion.
- **A pre-release** satisfies only a requirement that names a pre-release of the same version.
- **A program holds one version of a name.** Every requirement of a package in a program has to
  be satisfied by the one version installed. A release that has to live beside the one before it
  takes another name.

Which version to install, among those that satisfy everyone, is the package manager's to choose.
jac checks the choice and does not make it.

## Where a package goes

```text
<project>/
  jac.toml
  jac.lock
  eco/jac/
    grid/            the package: its jac.toml, its modules, nothing else
    grid.json        its record
    cells/
    cells.json
```

- **`eco/jac/<name>/` is the installed package `<name>`,** for the project being built. The
  packages an installed package asks for are installed there too, beside it: never inside it.
- **It may be a link** to a directory kept elsewhere, so a machine's packages can be shared
  between projects. jac reads through it and writes nothing in it.
- **`eco/jac/` is not tracked:** `jac install` adds it to the project's `.gitignore`.
- **Nothing outside the project is searched.**

### The record

Beside each package, `eco/jac/<name>.json` says what installed it:

```json
{ "format": 1, "installer": "jacpm", "from": { "registry": "https://packages.example.org" } }
```

| Key | Meaning |
|---|---|
| `format` | The record's format number, 1 |
| `installer` | Your program's name. jac's own is `jac` |
| `from` | Yours: whatever you need to install the same package again. jac copies it into `jac.lock` and does not read it. It holds no `null` |

- **Write a record for every package you install.** A package with none is refused (E5163).
- **Touch only the packages whose record names you.** jac's own fetcher (for a package a
  project declares by a repository) follows the same rule, and will not fetch over yours (E5165).

## What a project asks for

```toml
[packages]
grid = "1.2"                          # installed: yours to provide
shapes = { path = "../shapes" }       # a directory the project keeps
units = { git = "https://example.com/units.git", rev = "v1.2.0" }   # jac fetches it

[tool.jacpm]
registry = "https://packages.example.org"
```

- **A string is a requirement, and the package is an installed one.** These are the ones a
  package manager provides.
- **A table is a place,** and not yours: jac uses a `path` where it is, and fetches a `git`
  itself.
- **The project's own declaration decides the copy.** Where a project declares `cells` by `path`,
  the whole program uses that directory, and an installed package's `cells = "0.3"` is checked
  against its version. Do not install a package the project declares by a place.
- **`[tool.<name>]` is yours.** jac defines no key under `[tool]` and reads none: keep there
  what your program needs to know of a project.

## jac.lock

`jac.lock` pins every installed package the program needs, whoever installed it:

```toml
version = 2

[jac.grid]
version = "1.4.0"
digest = "sha256:9f2c5a0f6f1d7c1f3f0f8a4a1c6c4a0d6f6b6f0c3a8a3c1e7b2d5e9f4a1b0c3d"
installer = "jacpm"

[jac.grid.from]
registry = "https://packages.example.org"
```

- **`jac install` writes it, and nothing else does.** It pins each package from what is in
  `eco/jac/` and from its record. Read your entries, the ones whose `installer` names you, to
  install exactly what is pinned. Do not write the file.
- **The digest** is `sha256:` and the SHA-256, in hexadecimal, of these lines in the order of
  their paths: for each file of the package, its path from the package's directory with `/`
  between its parts, a zero byte, the SHA-256 of the file's bytes in hexadecimal, and a newline.
  A link to a directory inside a package is not followed.
- **The same version from the same `from` is the same files.** `jac install` refuses a package
  whose files changed under a pin (E5166). Install another version, or record another `from`, and
  it pins the package again.

### The order

| To | Run |
|---|---|
| Set a project up, or change what it uses | Your program, which installs what `jac.toml` asks for; then `jac install`, which pins it and installs what the packages need of npm and PyPI |
| Set up a fresh clone exactly as pinned | Your program, installing what `jac.lock` pins for it; then `jac install --frozen`, which fetches jac's own and verifies every package |

`jac install` stops at a package that is declared and not installed, naming every one (E5161).
A package jac fetched from a repository may ask for installed ones, so a project that uses both
kinds may need your program again after `jac install` has fetched.

## jac packages --json

`jac packages` prints what the compiler finds, and exits 1 when a package is missing or a
check fails. It fetches nothing, writes nothing and hashes nothing, so it is cheap to ask.

```json
{
  "format": 1,
  "project": "shop",
  "jac": "0.4.2",
  "interfaces": { "auth": 1, "bundler": 1, "jobs": 1, "limits": 1, "llm": 1, "schedule": 1, "store": 1, "transport": 1, "ui": 1 },
  "packages": [
    {
      "name": "grid",
      "kind": "library",
      "version": "1.4.0",
      "fills": "",
      "dir": "eco/jac/grid",
      "installer": "jacpm",
      "from": { "registry": "https://packages.example.org" },
      "state": "found",
      "asked": [
        { "by": "the project", "in": "jac.toml", "version": "1.2", "asks": "version 1.2 or later, below 2.0.0", "holds": true }
      ]
    },
    {
      "name": "cells",
      "kind": "package",
      "version": "",
      "fills": "",
      "dir": "eco/jac/cells",
      "installer": "",
      "from": {},
      "state": "missing",
      "asked": [
        { "by": "the library 'grid'", "in": "eco/jac/grid/jac.toml", "version": "0.3", "asks": "version 0.3 or later, below 0.4.0", "holds": false }
      ]
    }
  ],
  "problems": [
    {
      "code": "E5161",
      "message": "the package 'cells' is not installed as the library 'grid' asks, version 0.3 or later, below 0.4.0: nothing is at 'eco/jac/cells'",
      "file": "eco/jac/grid/jac.toml",
      "line": 7,
      "column": 1,
      "package": "cells"
    }
  ]
}
```

| Key | Meaning |
|---|---|
| `format` | This document's format number, 1 |
| `jac` | This jac's version, or `""` for one built from source, which refuses no package for its `jac` |
| `interfaces` | Each abstraction, and the version of its interface in this jac: what a plugin's `interface_ver` has to be |
| `packages` | Each package of the program, in the order it was first asked for |
| `packages[].kind` | `library` or `plugin`, or `package` for one whose `jac.toml` was not read |
| `packages[].fills` | For a plugin, the abstraction it fills |
| `packages[].dir` | Where its copy is, from the directory the command ran in |
| `packages[].installer`, `from` | Its record's, for an installed one |
| `packages[].state` | `found`, `missing` (nothing is at `dir`) or `wrong` (it is there and a check of it fails) |
| `packages[].asked` | Every declaration of it: `by` which package, `in` which `jac.toml`, what it `asks` in words, and `version`, or `path`, or `git` and `rev`. `holds` is whether the copy meets it |
| `problems` | What `jac check` would report of the project's packages: the `code`, the `message`, its place, and the `package` it is of, or `""` |

A package is yours to install when it is `missing`, or `wrong` with a version that does not hold,
and every declaration that decides it has a `version`. What a missing package would itself ask for
is not known until it is there: install it, and ask again.

## Format numbers

Three things here carry a format number. Each changes as a whole, under a new number: jac
reads one format of each and refuses another (E5164), and never reads two.

| What | Its number is | Now |
|---|---|---|
| A record, `eco/jac/<name>.json` | `format` | 1 |
| `jac.lock` | `version` | 2 |
| What `jac packages --json` prints | `format` | 1 |

`jac.lock` was at 1 while an entry held only what jac itself fetched from a repository. At 2 it
holds every installed package, with its installer and a SHA-256 digest.

The layout of `eco/jac/`, the keys of `[project]`, `[plugin]` and `[packages]`, and what a version
and a requirement are belong to the language, and change as it does.

## What a user sees

| Code | When |
|---|---|
| E5161 | A package is declared and not installed |
| E2220 | The installed version does not satisfy a package that asks for it, or two packages ask for one name from different places |
| E5163, E5164 | An installed package has no record, or the record is of another format |
| E2216 | An installed package says no `kind`, or another name than it is installed under |
| E2228 | A version or a requirement that is not one |
| E2229 | A package needs a later jac |
| E2230 | A plugin was written for another version of its abstraction's interface |
| E2221 | A library or a plugin declares a plugin |
| E2227 | A project declares a plugin and neither binds nor lists it |
| E5165 | `jac install` is asked to fetch a package where another installer's is |
| E5166 | An installed package is not what `jac.lock` pins |

`jac docs <code>` explains each.
