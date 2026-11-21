# Contributing

This repository holds two things, and a change is to one of them.

## The abstractions, the plugins, the libraries, the documentation and the examples

`abstractions/`, `libraries/`, `docs/` and `examples/` at the top are what `jac` (0.70.0 and on)
is released with. This repository holds the real copy of each: a change to one is a pull request
here, and a release of `jac` ships the commit of this repository it was built with.

- **`abstractions/`** holds the language's abstractions, a directory each. Its `jac.toml` declares
  the abstraction: the interface a plugin of it implements, the version of that interface
  (`interface_ver`), and its standard plugin. Its `contract.jac` is the contract: that interface
  and the types that cross it. A change that a plugin written for an interface would not survive
  raises its version. `common/contract.jac` is what every plugin may use, whatever it fills.
- **The standard plugins** are the directories beside those two files
  (`abstractions/store/sqlite`), each a package with its own `jac.toml`. A plugin imports its
  abstraction's contract, `common.contract`, the libraries it declares and the standard library,
  and nothing else of jac's. [Writing a plugin](docs/skills/writing-a-plugin/SKILL.md) says what
  one is made of.
- **`libraries/`** holds the libraries those plugins declare, each a package of
  `kind = "library"`: `sqlfile`.
- **`docs/`** is what `jac docs` prints. A page's `jac` examples are whole programs that `jac`
  compiles as the page says, and a page is listed in `docs/nav.json`.
- **`examples/`** holds programs written in Jac.

The compiler that builds these is not in this repository, and this repository runs no check of
its own on them yet. A pull request is checked when the compiler's own tests are run against it,
which a maintainer starts, and is merged when they pass. Install `jac` to try a change yourself:
a project uses a copy of a plugin by declaring it by its directory,

```toml
[packages]
sqlite_mine = { path = "../jac/abstractions/store/sqlite_mine" }

[store]
plugin = "sqlite_mine"
```

with the copy's `[project] name` and its class's path changed to match. A plugin declares the
libraries it uses by their place from its own directory (`sqlfile`, in `sqlite`'s `[packages]`),
so a copy made elsewhere says where they are from there.

## The reference design

`jac-reference/` is the open-source Jac compiler, with its own build, tests, documentation and
releases. [jac-reference/CONTRIBUTING.md](jac-reference/CONTRIBUTING.md) is its guide. Its
workflows, in `.github/`, build it from there.

## The install script

`scripts/install.sh` installs either compiler, and `scripts/test_install.sh` tests it with no
network: `bash scripts/test_install.sh`.
