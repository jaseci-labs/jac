---
description: A project's packages and manifests from every ecosystem in jac.toml and jac.lock - Jac packages ([packages]), libraries and plugins alike, by a version, a directory or a repository, the installed packages of eco/jac and what a version requirement means, what a library is and what it may not hold, npm trees ([npm.<tree>]) and the eco/ directory jac writes them into, Rust crates ([cargo."<dir>"]) and C modules ([c."<dir>"]) written where they stand, PyPI packages, jac install, remove, absorb, npm and cargo, what is tracked, and what is refused.
keywords: packages, [packages], libraries, Jac library, Jac package, version, version requirement, installed package, jac.lock, eco, eco/jac, npm tree, package.json, package-lock.json, node_modules, install, remove, absorb, frozen, Cargo.lock
---
# Packages

A project says which packages it takes, from every ecosystem, in `jac.toml`, and `jac.lock` records
exactly what was installed. The files another ecosystem's tools read (`package.json`,
`package-lock.json`) are not written by hand and not tracked: jac writes them from `jac.toml`
and `jac.lock` before it runs a tool, and takes back what the tool changed as it ends.

| Ecosystem | In `jac.toml` | In `jac.lock` | Installed in |
|---|---|---|---|
| Jac | `[packages]`, each package by its version or by where it is | `[jac.<name>]`, for each installed one, whoever installed it | `eco/jac/<name>`, for one declared by a version or a repository |
| npm | `[npm.<tree>]`, one for each tree of packages | `[npm.<tree>]` | `eco/<tree>/node_modules` |
| PyPI | `[dependencies.pypi]` | `[pypi]` | `.jac/venv` ([Python](../interop/python.md#pypi-packages)) |
| Rust | `[cargo."<directory>"]`, a crate's or a workspace's `Cargo.toml` | `[cargo."<directory>"]`, its `Cargo.lock` | nothing: cargo builds from the crate's directory |
| C and C++ | `[c."<directory>"]`, a C module's `cmodule.toml` | | nothing |

```sh
jac install                        # everything jac.toml lists
jac install --frozen               # exactly what jac.lock pins, as on a fresh clone
```

## Jac packages

A Jac package is a directory with a `jac.toml` and its modules. It is one of two kinds, which its
own `jac.toml` says, and never both ([Principles](../language/principles.md)):

| | Library | Plugin |
|---|---|---|
| Its `jac.toml` says | `kind = "library"` | `kind = "plugin"`, and what it fills ([Plugins](../apps/plugins.md#writing-a-plugin)) |
| It is declared in `[packages]` by | Each package whose modules import it | The project that binds it, and no other package |
| It is named by | A module's `import` | A binding in `jac.toml`, never an import |
| It may declare | Libraries | Libraries |

A package declares each package it uses in its `[packages]`: by its version, a string, or by
where it is, a table that names a directory or a repository at a revision. The table does not say
which kind a package is: the package's own `jac.toml` does.

```toml
[project]
name = "shop"

[packages]
grid = "1.2"
shapes = { path = "../shapes" }
units = { git = "https://example.com/units.git", rev = "v1.2.0" }
```

| A declaration | Means | The package is |
|---|---|---|
| `"1.2"` | Version 1.2.0 or later, below 2.0.0 ([Versions](#versions)) | [Installed](#installed-packages) in the project's `eco/jac/<name>` |
| `{ path = "..." }` | The package in that directory, from the directory of this `jac.toml` | Used where it is |
| `{ git = "...", rev = "..." }` | The package at that revision of a repository | [Fetched](#fetching-and-pinning) by `jac install` into `eco/jac/<name>` |

and its modules import the library's under its name:

<!-- example: not checked: needs the library beside the project -->
```jac
import shapes;
import from shapes.area { square }

with entry {
    print(square(3), shapes.NAME);
}
```

The library is a project like any other, published as it stands:

```toml
# ../shapes/jac.toml
[project]
name = "shapes"
kind = "library"
version = "0.1.0"

[packages]
units = { git = "https://example.com/units.git", rev = "v1.2.0" }

[dependencies.pypi]
numpy = ">=2"
```

- **A package's `version` is three numbers,** `MAJOR.MINOR.PATCH`, as
  [Semantic Versioning](https://semver.org) has it, with an optional pre-release (`1.3.0-rc.1`).
  One that is written and is not that is E2228.
- **A package may say the oldest jac it builds with,** `jac = "0.4"` in its `[project]`.
  It is a least version and no more: no author knows which later jac will break a package. A
  release of jac older than that refuses the package where it says so (E2229). A jac built
  from source is no release, and refuses none.
- **`shapes.area` is `area.jac` in the library's directory,** and `import shapes;` its
  `__init__.jac`. Inside the library, its modules import each other as a project's do: by a
  relative import (`import from .names { label }`) or from the library's root.
- **A module imports the libraries its own package declares.** `shapes` uses `units`, so `shapes`
  declares it. A module of the project that imports `units` is E2219 until the project declares it
  too: what a dependency brought is not the project's to use by accident.
- **A program holds one copy of a package.** Where the project declares `units`, the copy is the
  one the project names, and otherwise the one the first package to declare it names. Every other
  declaration of `units` has to hold of that copy, or the build is refused (E2220): a version
  requirement of its version, and a place by being the same place. A class belongs to its module,
  so two copies would be two types.
- **A library depends on no plugin.** Its `[packages]` declares none and its `jac.toml` binds no
  abstraction (E2221), and none of its modules imports one (E2218). It uses the language's
  abstractions (`root`, `by llm()`), and the project that uses it says what carries them out.
- **A library's name is its own.** A directory or a module of the project named as a declared
  library is E2222: an import would name either.
- **A plugin declares libraries the same way,** in its own `[packages]`, and no plugin: only a
  project declares one (E2221), and a plugin it declares is one it binds or lists (E2227,
  [Plugins](../apps/plugins.md#binding-a-plugin)).
- **A plugin's modules import its abstraction's contract, `common.contract`, the libraries it
  declares and the standard library,** and nothing else of jac's: no module of stdjac, and no
  other abstraction's contract (E2232). A library a plugin declares is held to the same, with
  `common.contract` the one contract it imports
  ([Plugins](../apps/plugins.md#what-a-plugin-imports)). jac's own library `sqlfile`, which its
  `sqlite` and `accounts` plugins declare by its place in jac's tree, is such a library.
- **No package declares an abstraction** (E2217). The abstractions are jac's own, each a directory
  of its `abstractions/` ([Plugins](../apps/plugins.md#the-abstractions)).
- **`[libraries]` and `[plugins]` are no tables of a `jac.toml`** (E2226): a package's packages
  are in `[packages]`.

### Versions

- **A requirement is the least version asked for:** `"1"`, `"1.2"` or `"1.2.3"`. It is satisfied
  by that version and every later one in which its left-most number that is not zero is
  unchanged:

  | Requirement | Satisfied by |
  |---|---|
  | `"1.2"`, `"1.2.0"` | 1.2.0 or later, below 2.0.0 |
  | `"1"` | 1.0.0 or later, below 2.0.0 |
  | `"0.4"` | 0.4.0 or later, below 0.5.0 |
  | `"0.0.3"` | 0.0.3 alone |

- **There is no other form:** no range, no exact version, no exclusion (E2228). An exact version
  is what a lock pins. A release that breaks its users and has to live beside the one before it
  takes a new name (`shapes2`), since a program holds one copy of a name.
- **A pre-release** (`1.3.0-rc.1`) satisfies only a requirement that names a pre-release of the
  same version (`"1.3.0-rc.1"`).
- **A package asked for by version states one.** One whose `jac.toml` has no `version` satisfies
  no requirement.

jac says what a version and a requirement are because the compiler checks one against the
other. It does not choose a version: that is a package manager's work.

### Installed packages

A package declared by its version is an installed one. The compiler finds it in the project's
`eco/jac/<name>`, a directory holding the package's files with its `jac.toml` at the top, and
does not ask how it came to be there: a package manager is a program of its own, which puts
packages in that directory ([Writing a package manager](package-managers.md)).

- **The directory is the project's:** the one being built. A package's own requirements are found
  there too, never in the package's directory. So one directory holds one version of each name,
  libraries and plugins alike.
- **It may be a link** to a directory a package manager keeps elsewhere. The compiler reads
  through it, and writes nothing in it.
- **Beside it is a record of what installed it,** `eco/jac/<name>.json`:

  ```json
  { "format": 1, "installer": "jacpm", "from": { "registry": "https://packages.example.org" } }
  ```

  `installer` is the name of the program that put the package there, `from` is that program's
  own, which jac does not read, and `format` is the record's format, 1. An installed package
  with no record is refused (E5163), and so is a record of another format (E5164): a package
  someone keeps by hand is declared by `path`.
- **An installer touches only the packages whose record names it.** `jac install` leaves
  another's packages and records as they are, and does not fetch over one (E5165).
- **Nothing is machine-wide:** no directory outside the project is searched, and no environment
  variable adds one.
- **What is not there is said where it was asked for** (E5161), with what was asked and by which
  package, and so is a copy whose version does not satisfy a declaration (E2220).
- **A project builds against its own checkout of a package** by declaring it by `path`. The
  project's declaration decides the copy the whole program holds, so an installed package that
  asks for `units = "0.3"` uses the project's `units = { path = "../units" }`, whose version has
  to satisfy that.

### Fetching and pinning

A package declared by its directory is used where it is. One declared by a repository is fetched by
`jac install`:

```text
$ jac install
jac install: the library units at 6c8f55b32d8a in eco/jac/units
```

- **It is fetched into `eco/jac/<name>`,** which is not tracked: `jac install` adds `eco/jac/`
  to the project's `.gitignore`. jac is the installer of what it fetches, and records it as
  any installer does: `eco/jac/<name>.json` names `jac`, and its `from` holds the repository,
  the revision asked for and the commit. A build that finds it missing, or fetched for another `git` or
  `rev` than `jac.toml` now has, is E5161, and `jac install` is the fix.
- **`jac.lock` pins the commit,** as it pins every installed package ([below](#the-lock)). A `rev`
  that is a branch is pinned at the commit it named when it was first fetched, and stays there
  until `jac.toml` asks for another `rev`.
- **`jac install --frozen`** fetches exactly the commits `jac.lock` pins, and fails for a package
  it pins nothing for, or whose files are not the ones it pinned.
- **Every package the project's packages declare is fetched too,** each once, into the same
  directory.

### The lock

`jac.lock` holds one entry for each installed package the program needs, whoever installed it. A
package declared by its directory has none.

```toml
[jac.grid]
version = "1.4.0"
digest = "sha256:9f2c5a0f6f1d7c1f3f0f8a4a1c6c4a0d6f6b6f0c3a8a3c1e7b2d5e9f4a1b0c3d"
installer = "jacpm"

[jac.grid.from]
registry = "https://packages.example.org"

[jac.units]
version = "0.1.0"
digest = "sha256:ebe3029117f00a21e55d5167bcfea5d77279d74f1eb847daf0195c67eca3aecd"
installer = "jac"

[jac.units.from]
git = "https://example.com/units.git"
rev = "v1.2.0"
commit = "6c8f55b32d8a611f0d288e5035357a17934bfd9b"
```

- **`jac install` is the one writer of `jac.lock`.** It pins each installed package from what
  is in `eco/jac/` and from the record beside it: the package's `version`, its `installer`, the
  installer's `from`, and a `digest` of its files. A package manager reads the entries that name
  it, to install exactly what they pin.
- **The digest is SHA-256,** and any program can compute it. For each file of the package, a line:
  its path from the package's directory, with `/` between its parts, a zero byte, the SHA-256 of
  the file's bytes in hexadecimal, and a newline. The digest is `sha256:` and the SHA-256 of
  those lines, in the order of their paths. A link to a directory inside a package is not
  followed.
- **`jac install` pins a package again** when its version or its `from` changed. It refuses
  one whose files changed under the same version from the same place (E5166): that is not the
  package that was pinned.
- **A declared package that is not installed stops it** (E5161): it names every one, with who
  asks for it and for what.
- **`jac install --frozen` writes nothing.** Every package the program needs is installed and
  pinned, and its version, its record and its files are what is pinned, or it stops (E5166),
  naming the package and what installed it.
- **What nothing declares any more is no longer pinned.** jac removes the package if it
  fetched it, and leaves another installer's where it is.
- **On a fresh clone,** the project's package manager installs what `jac.lock` pins for it, and
  `jac install --frozen` fetches jac's own and verifies them all.
- **The lock's format is 2.** A lock of another format is E5164.

### What a project's packages are: jac packages

```text
$ jac packages
grid 1.4.0: a library, found, in eco/jac/grid, which 'jacpm' installed
    the project asks for version 1.2 or later, below 2.0.0
cells: a package, missing, in eco/jac/cells
    the library 'grid' asks for version 0.3 or later, below 0.4.0: not met

Interfaces: auth 1, bundler 1, jobs 1, limits 1, llm 1, schedule 1, store 1, transport 1, ui 1

eco/jac/grid/jac.toml:7:1: error[E5161]: the package 'cells' is not installed as the library 'grid' asks, version 0.3 or later, below 0.4.0: nothing is at 'eco/jac/cells'
```

- **It prints the project's Jac packages as the compiler finds them:** each one's name, version
  and kind (and what a plugin fills), where its copy is and what installed it, every package that
  asks for it and for what, and whether it is found, missing, or wrong.
- **Then the version of each abstraction's interface** in this jac, which is what a plugin's
  `interface_ver` has to be ([Plugins](../apps/plugins.md#the-abstractions)), and every problem
  with its place in a `jac.toml`: the ones `jac check` reports.
- **It reads and changes nothing:** it fetches no package, writes no lock, hashes no file.
- **It exits 1 when a package is missing or a check fails,** so a script can ask whether a
  project's packages are installed.
- **`--json` prints the same as one document,** for a program to read
  ([Writing a package manager](package-managers.md#jac-packages---json)).

### What a package needs of npm and PyPI

A library or a plugin says what it needs of other ecosystems as a project does, and
`jac install` installs it with the project's own:

- **Its `[dependencies.pypi]`** is resolved together with the project's, into the project's
  `.jac/venv`, and pinned in `jac.lock`'s `[pypi]`.
- **The `dependencies` of its `[npm.<tree>]` tables** are written into every npm tree of the
  project, with the tree's own. Two askers of one npm package agree on its range (E5162).
- **Neither is written into the project's `jac.toml`.** What `jac npm` takes back from a tree is
  the project's own packages.

## npm trees

An npm tree is one package and the packages it depends on: one `package.json`, one lock, one
`node_modules`. `jac.toml`'s `[npm.<tree>]` table is that tree's `package.json`, key for key, with
npm's own names for its keys:

```toml
[npm.web]
private = true
type = "module"

[npm.web.dependencies]
nanoid = "^5.1.0"
lodash = "^4.17.21"

[npm.web.devDependencies]
"@types/lodash" = "^4.17.0"
```

```sh
jac install --npm nanoid lodash --tree web    # add packages, making the tree if it is new
jac remove --npm lodash                       # take one out
```

`--tree` names the tree. A project's only tree needs no naming.

### Which tree a space's imports use

A project with one tree uses it everywhere: for every space, and for a program of no space. A
project with several says which is each space's, in `jac.toml`:

```toml
[spaces.site]
npm = "web"

[spaces.phone]
npm = "mobile"
```

A space naming a tree `jac.toml` does not declare is E1287, and a module importing from npm where
nothing says which of several trees is its own is E1288.

## The `eco/` directory

Each tree has a directory, `eco/<tree>`, which is where its tools run:

```text
shop/
    jac.toml
    jac.lock
    main.jac
    eco/
        web/
            vite.config.ts        yours, tracked
            index.html            yours, tracked
            package.json          written by jac from jac.toml
            package-lock.json     written by jac from jac.lock
            node_modules/         installed by jac install
            .jac/                 the tree's spaces, compiled
```

- **What you write there** is what a tool's own configuration is written in, and any file of
  yours that imports the tree's packages: a bundler's configuration, `tsconfig.json`,
  `index.html`, a stylesheet that imports a package. A tool finds a file's packages by looking in
  the directories above the file, so such a file is under its tree.
- **What jac writes there** is not tracked. The first time it writes a tree it adds these
  lines to the project's `.gitignore`:

  ```text
  eco/*/package.json
  eco/*/package-lock.json
  eco/*/node_modules/
  ```

  `.jac/` is ignored as the project's own is.
- **A JavaScript space is compiled there**, into `eco/<tree>/.jac/build`, so that its modules find
  the tree's packages and its `tsconfig.json` as any file of the tree does.

## Rust crates and C modules

A crate's `Cargo.toml`, the `Cargo.lock` beside it and a [C module](../interop/c-modules.md)'s
`cmodule.toml` are tables of `jac.toml` and `jac.lock` too, each named by its directory from the
project's root:

```toml
[cargo.adder]
[cargo.adder.package]
name = "adder"
version = "0.1.0"
edition = "2024"

[c.geom]
sources = ["geom.c"]

[c.geom.target.linux]
libs = ["m"]
```

- **A table is the manifest's own text**, its tables named under the directory's. Comments are
  kept, and the file jac writes from it is the file that was taken in, byte for byte.
- **The files are written where they stand**, `adder/Cargo.toml` and `geom/cmodule.toml`, not
  under `eco/`: cargo finds a crate's sources, and its workspace, from where its manifest is.
  jac writes them before any command looks for them, making a directory that holds nothing
  else, and lists each in the project's `.gitignore`.
- **`jac absorb <directory>`** takes in every `Cargo.toml` and `cmodule.toml` under a directory,
  into the `jac.toml` of the project each is in. A workspace is a table for its root and one for
  each member.
- **`jac cargo`** writes the project's manifests first, and takes back what cargo changed as it
  ends (`cargo add`, `cargo update`).

A program with no `jac.toml` above it keeps its manifests as files: a loose `main.jac` beside a
`geom/cmodule.toml` builds as it did.

## Running npm

`jac npm` and `jac npx` run in a tree: the one whose directory they are run in or under, or
the project's only tree. jac writes the tree's `package.json` and lock first, and when npm ends
it takes what npm wrote back into `jac.toml` and `jac.lock`:

```text
$ jac npm pkg set description="A shop"
jac: jac.toml took what npm wrote in eco/web
```

Only the tree's table changes. The rest of `jac.toml`, its comments with it, is as it was.

In a directory that is no Jac project (no `jac.toml` in it or above it), `jac npm` is npm as it
is anywhere, on that directory's own `package.json`.

## Taking in a manifest you already have

`jac absorb` makes a tree of a `package.json`, the `package-lock.json` beside it and their
`node_modules`:

```sh
jac absorb --tree web       # the package.json in this directory
jac absorb mobile           # the one in mobile/, as the tree `mobile`
```

The manifest becomes `[npm.<tree>]`, the lock becomes `jac.lock`'s, and the three move to
`eco/<tree>`. A package the manifest names by a path (`"file:../kit"`) is named from the tree's
directory afterwards, and is resolved again by the next `jac install`. A manifest that cannot
be taken whole is not taken at all: nothing is written and nothing moves.

## What keeps the two in step

- **What jac writes is `jac.toml` and `jac.lock`, and nothing else.** A tree's `package.json`
  holds what its table holds, in the order the table has it.
- **npm resolves, jac records.** `jac.lock`'s `[npm.<tree>]` is the lock npm wrote, key for key.
  Written back, it is the same file byte for byte.
- **What one side cannot hold is refused, never dropped.** JSON's `null` has no value in TOML
  (E5156), and TOML's dates, `inf` and `nan` have none in JSON (E5155). A tree with `workspaces`
  is refused (E5159): another package is another tree.
- **A build checks what is installed.** A tree whose `node_modules` was not installed from
  `jac.toml` and `jac.lock` as they are now is E5160, and `jac install` is the fix. It runs npm
  only for a tree that is not as pinned.

## What goes wrong

| What jac says | Why |
|---|---|
| `install: jac.toml declares no npm tree: name the one to make, --tree <tree>` | `--npm` in a project with no tree yet |
| `install: jac.toml declares the npm trees web, mobile: say which, --tree <tree>` | `--npm` in a project with several |
| `npm: jac.toml declares the npm trees web, mobile: run it in the one it is for, eco/<tree>` | `jac npm` at the top of a project with several |
| `install --frozen: jac.lock pins nothing for the npm tree 'web'; run jac install` | `--frozen` before the tree was ever locked |
| `absorb: jac.toml already declares the npm tree 'web'` | The name is taken: give another with `--tree` |
| E5155, E5156, E5157, E5158, E5159 | A value or a form one file cannot hold of the other: `jac docs E5156`. E5157 is also a `Cargo.toml` or `cmodule.toml` whose text cannot be moved under a table's name as it is |
| E5160 | A tree not installed as pinned: `jac install` |
| E5161 | A package that is not installed as a declaration asks: one declared by a version that is not in `eco/jac/`, or one from a repository that is not fetched (`jac install`) |
| E5162 | Two askers of one npm package, at different ranges |
| E5163, E5164, E5165 | An installed package with no record of what installed it, a record or a `jac.lock` of another format, and a package another installer put where `jac install` is asked to fetch one |
| E5166 | An installed package that is not what `jac.lock` pins: its files changed, or under `--frozen` its version or where it came from |
| `install --frozen: jac.lock pins nothing for the package 'units' as jac.toml asks for it; run jac install` | `--frozen` after `jac.toml` came to ask for a package, or for another `git` or `rev` of one |
| E2216, E2219, E2220, E2221, E2222 | A package that is not where it is declared or is neither a library nor a plugin, a library imported that the package does not declare, a declaration that does not hold of the copy the program holds (another place, or a version that does not satisfy it), a library or a plugin that declares or binds a plugin, a library whose name the project's tree also has: `jac docs E2219` |
| E2226, E2227, E2228, E2229 | A `[libraries]` or a `[plugins]` table, a plugin a project declares and never uses, a version or a requirement that is not one, a package that needs a later jac |
| E2217, E2232 | A package that declares an abstraction; a plugin, or a library a plugin declares, that imports a module of stdjac or the contract of an abstraction it does not fill |
| E1287, E1288 | A space's tree is not declared, or not named among several |
