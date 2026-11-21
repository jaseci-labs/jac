# Jac

The Jac programming language: its compiler `jac`, its standard library of abstractions, its
standard plugins, its documentation, and the language's open-source reference design.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh | bash
```

That installs `jac`: one download with the compiler and everything a project around a Jac program
needs (CPython, Node, Clang and Rust), for Linux x86_64 and arm64 and macOS on Apple Silicon.
[Install](docs/start/install.md) has the options.

```sh
echo 'with entry { print("hello from jac"); }' > hello.jac
jac run hello.jac
```

The documentation ships with `jac`, for the version installed: `jac docs` prints its map. It is
also here, in [`docs/`](docs/), starting at [docs/start](docs/start/index.md).

## What is here

| | |
|---|---|
| [`docs/`](docs/) | The documentation `jac docs` prints, and the skills an agent loads |
| [`abstractions/`](abstractions/) | The language's abstractions, a directory each: what carries out `root`, `by llm()`, `:protect`, `@job` and the rest. Each declares itself (`jac.toml`), holds the contract a plugin of it implements (`contract.jac`), and holds its standard plugins: `sqlite`, `accounts`, `http`, `anthropic`, `react`, `vite` and the others |
| [`libraries/`](libraries/) | Libraries the standard plugins declare: `sqlfile`, a SQLite file at a layout |
| [`examples/`](examples/) | Programs written in Jac |
| [`jac-reference/`](jac-reference/) | The reference design: the open-source Jac compiler, with its own documentation, tests and releases |
| [`scripts/install.sh`](scripts/install.sh) | The install script, for both compilers |

## The two compilers

`jac` is released here from version 0.70.0. Its compiler is not in this repository; what it is
built on that a program meets is: the contracts and the plugins of `abstractions/`, and the
libraries of `libraries/`, are compiled into the programs it builds, and a release ships them,
and `docs/`, as they are here.

The reference design, in [`jac-reference/`](jac-reference/), is the open-source compiler that Jac
was first released as. It is built, tested and released from this repository at its own versions
(0.40 and on), and is installed with the same script:

```sh
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh | bash -s -- --reference
```

Both install the command `jac`, so a machine has one or the other, and installing one replaces
the other. Where the two differ as languages is
[Coming from the reference design](docs/start/coming-from-the-reference-design.md).

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) says where a change goes. In short: a change to the standard
library, a plugin, the documentation or an example is a pull request against the directory at
the top; a change to the reference design is one against `jac-reference/`, whose own
[guide](jac-reference/CONTRIBUTING.md) has its build and its tests.

## License

[MIT](LICENSE).
