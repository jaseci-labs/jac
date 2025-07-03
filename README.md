<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://www.jac-lang.org//assets/logo.png">
    <source media="(prefers-color-scheme: light)" srcset="https://www.jac-lang.org//assets/logo.png">
    <img alt="Jaclang logo" src="https://www.jac-lang.org//assets/logo.png" width="20%">
  </picture>

  [Jac Website] | [Getting started] | [Learn] | [Documentation] | [Contributing]

  [Jac]: https://www.jac-lang.org/
  [Jac Website]: https://www.jac-lang.org/
  [Getting Started]: https://www.jac-lang.org/learn/getting_started/
  [Learn]: https://www.jac-lang.org/learn/getting_started/
  [Documentation]: https://www.jac-lang.org/learn/getting_started/
  [Contributing]: .github/CONTRIBUTING.md
</div>

# Jaseci Ecosystem

Welcome to the Jaseci project. This repository houses the core libraries and tooling for building next generation applications with the Jac programming language. Jac is an innovative programming language that extends Python's semantics while maintaining full interoperability with the Python ecosystem. It introduces cutting-edge programming models and abstractions specifically designed to minimize and hide complexity, embrace AI-forward development, and automate categories of common software systems that typically require manual implementation. Despite being relatively new, Jac has already proven its production-grade capabilities, currently powering several real-world applications across various use cases.

Jaseci serves as the implementation of the Jac runtime, functioning in a relationship similar to how CPython serves as the reference implementation for Python. This runtime environment enables Jac code to execute with its enhanced features while maintaining the seamless Python interoperability that makes the language particularly accessible to Python developers.

The project brings together a set of components that work seamlessly together:

- **[`jaclang`](jac/):** The Jac programming language, a drop‑in replacement for and superset of Python.
- **[`jac-cloud`](jac-cloud/):** Cloud‑native utilities that automatically turn a Jac application into a production-ready server stack.
- **[`jac VSCE`](jac/support/vscode_ext):** The official VS Code extension for Jac.
- **[`mtllm`](jac-mtllm/):** Easy integration of large language models into your applications.

## Quick Start

Install the language and tools directly from PyPI:

```bash
pip install jaclang jac-cloud mtllm
```

After installation run `jac --help` to explore the available commands.

## Documentation

Comprehensive guides and API references are available at the [official documentation site][Documentation].

## Awesome Jaseci Projects 🚀

Explore these impressive projects built with Jaseci! These innovative applications showcase the power and versatility of the Jaseci ecosystem. Consider supporting these projects or getting inspired to build your own.

| Project | Description | Link |
|---------|-------------|------|
| **Jivas** | An Agentic Framework for rapidly prototyping and deploying graph-based, AI solutions | [GitHub](https://github.com/TrueSelph/jivas) |
| **Tobu** | Your AI-powered memory keeper that captures the stories behind your photos and videos | [Website](https://tobu.life/) |
| **TrueSelph** | A Platform Built on Jivas for building Production-grade Scalable Agentic Conversational AI solutions | [Website](https://trueselph.com/) |
| **Myca** | An AI-powered productivity tool designed for high-performing individuals | [Website](https://www.myca.ai/) |
| **Pocketnest Birdy AI** | A Commercial Financial AI Empowered by Your Own Financial Journey | [Website](https://www.pocketnest.com/) |
| **LittleX** | A lightweight social media application inspired by X, developed using the Jaseci Stack | [GitHub](https://github.com/Jaseci-Labs/littleX) |
| **Visit_Zoo** | An interactive zoo simulation with clickable sections, images, and videos | [GitHub](https://github.com/Thamirawaran/Visit_Zoo) |

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## License

All Jaseci open source software is distributed under the terms of both the MIT license with a few other open source projects vendored
within with various other licenses that are very permissive.

See [LICENSE-MIT](.github/LICENSE) for details.

