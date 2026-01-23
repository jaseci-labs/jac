<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://www.jac-lang.org/assets/logo.png">
    <source media="(prefers-color-scheme: light)" srcset="https://www.jac-lang.org/assets/logo.png">
    <img alt="Jaclang Programming Language: Unique and Powerful programming language that runs on top of Python"
         src="https://www.jac-lang.org/assets/logo.png"
         width="20%">
  </picture>

[Jac Website] | [Getting started] | [Learn] | [Documentation] | [Contributing]

  [![PyPI version](https://img.shields.io/pypi/v/jaclang.svg)](https://pypi.org/project/jaclang/) [![Tests](https://github.com/Jaseci-Labs/jaclang/actions/workflows/run_pytest.yml/badge.svg)](https://github.com/Jaseci-Labs/jaclang/actions/workflows/run_pytest.yml) [![codecov](https://codecov.io/github/chandralegend/jaclang/graph/badge.svg?token=OAX26B0FE4)](https://codecov.io/github/chandralegend/jaclang)
</div>

This is the main source code repository for the [Jac] programming language. It contains the compiler, language server, and documentation.

[Jac]: https://www.jac-lang.org/
[Jac Website]: https://www.jac-lang.org/
[Getting Started]: https://docs.jaseci.org/learn/tour/
[Learn]: https://docs.jaseci.org/jac_book/
[Documentation]: https://docs.jaseci.org/jac_book/
[Contributing]: https://docs.jaseci.org/internals/contrib/

## What and Why is Jac?

- **Native Superset of Python and TypeScript/JavaScript** - Jac is a native superset of both Python and TypeScript/JavaScript, meaning both ecosystems (PyPI and npm) are directly interoperable with Jac without any trickery (no interop interface needed). Every Jac program can be ejected to pure Python, and Python programs can be transpiled to Jac.

- **AI as a Programming Language Constructs** - Jac includes a novel (neurosymbolic) language construct that allows replacing code with generative AI models themselves. Jac's philosophy abstracts away prompt engineering. (Imagine taking a function body and swapping it out with a model.)

- **New Modern Abstractions** - Jac introduces a paradigm that reasons about persistence and the notion of users as a language level construct. This enables writing simple programs for which no code changes are needed whether they run in a simple command terminal, or distributed across a large cloud. Jac's philosophy abstracts away dev ops and container/cloud configuration.

- **Jac Improves on Python** - Jac makes multiple thoughtful quality-of-life improvements/additions to Python. These include new modern operators, new types of comprehensions, new ways of organizing modules (i.e., separating implementations from declarations), etc.

## Quick Start

To install Jac, run:

```bash
pip install jaclang
```

Run `jac` in the terminal to see whether it is installed correctly.

Read ["Getting Started"] from [Docs] for more information.

["Getting Started"]: https://docs.jaseci.org/learn/tour/
[Docs]: https://docs.jaseci.org/jac_book/

## Installing from Source

If you really want to install from source (though this is not recommended):

```bash
# with a local clone at `path/to/repo`:
pip install path/to/repo/jac
# or to have `pip` clone for you:
pip install git+https://github.com/jaseci-labs/jaseci#subdirectory=jac
```

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
