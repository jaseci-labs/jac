# Contributing

This repository holds two things, and a change is to one of them.

## The standard library, the plugins, the documentation and the examples

`stdjac/`, `plugins/`, `docs/` and `examples/` at the top are what `jac` (0.70.0 and on) is
released with. This repository holds the real copy of each: a change to one is a pull request
here, and a release of `jac` ships the commit of this repository it was built with.

- **`stdjac/`** declares the language's abstractions in its `jac.toml`, each with the interface a
  plugin of it implements and the version of that interface (`interface_ver`). A change that a
  plugin written for an interface would not survive raises that version.
- **`plugins/`** holds the standard plugins, each a package with its own `jac.toml`.
  [Writing a plugin](docs/skills/writing-a-plugin/SKILL.md) says what one is made of.
- **`docs/`** is what `jac docs` prints. A page's `jac` examples are whole programs that `jac`
  compiles as the page says, and a page is listed in `docs/nav.json`.
- **`examples/`** holds programs written in Jac.

The compiler that builds these is not in this repository, and this repository runs no check of
its own on them yet. A pull request is checked when the compiler's own tests are run against it,
which a maintainer starts, and is merged when they pass. Install `jac` to try a change yourself:
a project uses a copy of a plugin by declaring it by its directory,

```toml
[packages]
sqlite_mine = { path = "../jac/plugins/sqlite_mine" }

[store]
plugin = "sqlite_mine"
```

with the copy's `[project] name` and its class's path changed to match.

## The reference design

`jac-reference/` is the open-source Jac compiler, with its own build, tests, documentation and
releases. [jac-reference/CONTRIBUTING.md](jac-reference/CONTRIBUTING.md) is its guide. Its
workflows, in `.github/`, build it from there.

## The install script

`scripts/install.sh` installs either compiler, and `scripts/test_install.sh` tests it with no
network: `bash scripts/test_install.sh`.
