<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://www.jac-lang.org/assets/logo.png">
    <source media="(prefers-color-scheme: light)" srcset="https://www.jac-lang.org/assets/logo.png">
    <img alt="Jac Programming Language: compiles to Python bytecode, JavaScript, and native machine code"
         src="https://www.jac-lang.org/assets/logo.png"
         width="20%">
  </picture>

[Jac Website] | [Getting started] | [Learn] | [Documentation] | [Contributing]

  [![Latest release](https://img.shields.io/github/v/release/jaseci-labs/jaseci.svg)](https://github.com/jaseci-labs/jaseci/releases/latest) [![Tests](https://github.com/Jaseci-Labs/jaclang/actions/workflows/run_pytest.yml/badge.svg)](https://github.com/Jaseci-Labs/jaclang/actions/workflows/run_pytest.yml) [![codecov](https://codecov.io/github/chandralegend/jaclang/graph/badge.svg?token=OAX26B0FE4)](https://codecov.io/github/chandralegend/jaclang)
</div>

This is the main source code repository for the [Jac] programming language. It contains the compiler, language server, and documentation.

[Jac]: https://www.jac-lang.org/
[Jac Website]: https://www.jac-lang.org/
[Getting Started]: https://docs.jaseci.org/learn/tour/
[Learn]: https://docs.jaseci.org/jac_book/
[Documentation]: https://docs.jaseci.org/jac_book/
[Contributing]: https://docs.jaseci.org/internals/contrib/

## What and Why is Jac?

- **Ecosystem-Native Multi-Target Compilation** - With Python-like syntax, Jac compiles to Python bytecode, JavaScript, and native machine code (C-ABI compatible). This means every library in PyPI, npm, and native C ecosystems is directly usable from Jac without interop wrappers or foreign function interfaces. Every Jac program can also be ejected to readable Python, and Python programs can be transpiled to Jac.

- **AI as a Programming Language Constructs** - Jac includes a novel (neurosymbolic) language construct that allows replacing code with generative AI models themselves. Jac's philosophy abstracts away prompt engineering. (Imagine taking a function body and swapping it out with a model.)

- **New Modern Abstractions** - Jac introduces a paradigm that reasons about persistence and the notion of users as a language level construct. This enables writing simple programs for which no code changes are needed whether they run in a simple command terminal, or distributed across a large cloud. Jac's philosophy abstracts away dev ops and container/cloud configuration.

- **Quality-of-Life Beyond Python** - Jac introduces modern operators, new comprehension forms, and module organization that separates declarations from implementations -- going beyond what Python offers while remaining familiar.

## Quick Start

Jac ships as a single self-contained native binary -- no Python, pip, or uv required. To install it, run:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

Run `jac` in the terminal to see whether it is installed correctly.

Read ["Getting Started"] from [Docs] for more information.

["Getting Started"]: https://docs.jaseci.org/learn/tour/
[Docs]: https://docs.jaseci.org/jac_book/

## Building from Source

The `jac` binary is built with [Zig](https://ziglang.org/) from this source tree (the build reads metadata from `jac.toml`; there is no `pyproject.toml` or pip install). For a full development environment, run the repository's bootstrap script:

```bash
# from the repository root
./scripts/fresh_env.sh
```

This builds the `jac` binary and puts it on your PATH. See [`launcher/README.md`](launcher/README.md) for the low-level `zig build` steps and the binary's internals.

## Getting Help

Submit and issue! Community links coming soon.

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## License

Jaclang is distributed under the terms of both the MIT license with a few other open source projects vendored
within with various other licenses that are very permissive.

See [LICENSE-MIT](.guthub/LICENSE), and
[COPYRIGHT](COPYRIGHT) for details.

## Trademark

[Jaseci][jaseci] owns and protects the Jaclang trademarks and logos (the "Jaclang Trademarks").

If you want to use these names or brands, please read the [media guide][media-guide].

Third-party logos may be subject to third-party copyrights and trademarks. See [Licenses][policies-licenses] for details.

[jaseci]: https://jaseci.org/
[media-guide]: https://jaseci.org/policies/logo-policy-and-media-guide/
[policies-licenses]: https://www.jaseci.org/policies/licenses
