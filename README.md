<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/docs/assets/logo.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/docs/assets/logo.png">
    <img alt="Jaclang logo" src="docs/docs/assets/logo.png" width="80px">
  </picture>

  <h1>Jaseci</h1>
  <h3>The AI-Native Stack for Python Developers</h3>

  <p>
    <a href="https://pypi.org/project/jaclang/">
      <img src="https://img.shields.io/pypi/v/jaclang.svg?style=flat-square" alt="PyPI version">
    </a>
    <a href="https://codecov.io/gh/Jaseci-Labs/jaseci">
      <img src="https://img.shields.io/codecov/c/github/Jaseci-Labs/jaseci?style=flat-square" alt="Code Coverage">
    </a>
    <a href="https://discord.gg/6j3QNdtcN6">
  <img src="https://img.shields.io/badge/Discord-Community-blue?style=flat-square&logo=discord" alt="Discord">
</a>
  </p>

[**Website**](https://www.jaseci.org/) · [**Full Documentation**](https://www.jac-lang.org/) · [**Contribution Guide**](https://www.jac-lang.org/internals/contrib/)

<!-- =======
  [jac-lang.org] | [Getting Started] | [Contributing]

  [jac-lang.org]: https://www.jaseci.org/
  [Getting Started]: https://www.jac-lang.org/learn/getting_started/
  [Contributing]: https://www.jac-lang.org/internals/contrib/ -->
</div>

# Jaseci Ecosystem

Welcome to the Jaseci project. This repository houses the core libraries and tooling for building next-generation applications with the Jac programming language.

Jaseci serves as the implementation stack for the Jac programming language, and is packaged as a simple Python library. This runtime stack enables Jac code to execute with its enhanced features while maintaining the seamless Python interoperability that makes the language particularly accessible to Python developers.

The project brings together a set of components that work seamlessly together:

- **[`jaclang`](jac/):** The Jac programming language, a drop‑in replacement for and superset of Python.
- **[`byllm`](jac-byllm/):** Plugin for Jac enabling easy integration of large language models into your applications.
- **[`jac-client`](jac-client/):** Plugin for Jac to build full-stack web applications with React-like components, all in one language.
- **[`jac VSCE`](https://github.com/jaseci-labs/jac-vscode/blob/main/README.md):** The official VS Code extension for Jac.

---

## Core Concepts

Jac is an innovative programming language that extends Python's semantics while maintaining full interoperability with the Python ecosystem. It introduces cutting-edge programming models and abstractions specifically designed to hide complexity, embrace AI-forward development, and automate categories of common software systems that typically require manual implementation. Despite being relatively new, Jac has already proven its production-grade capabilities, currently powering several real-world applications across various use cases. Jaseci's power is rooted in four key principles.

- **AI-Native:** Treat AI models as a native type. Weave them into your logic as effortlessly as calling a function with first-class AI abstractions.

- **Agentic Object-Spatial Programming Model:** Model your domain as a graph of objects and deploy agentic **walker** objects to travel through your object graph performing operations in-situ. Intuitively model AI state, the problem domain, and data.

- **Python Superset:** Use the entire Python ecosystem (`pip`, `numpy`, `pandas`, etc.) without friction. All valid Python code is also valid Jac code, ensuring a gentle learning curve.

- **Cloud-Native:** Deploy your application as a production-ready API server with a single `jac start` command, scaling from local prototype development to a distributed cloud environment with zero code changes.

---

## Installation & Setup

<details>
<summary><strong>Install from PyPI (Recommended)</strong></summary>

<br>

Get the complete, stable toolkit from PyPI:

```bash
pip install jaclang[all]
```

This is the fastest way to get started with building applications.

</details>

<details>
<summary><strong>Install from Source (For Contributors)</strong></summary>

<br>

If you plan to contribute to Jaseci, install it in editable mode from a cloned repository:

```bash
git clone https://github.com/Jaseci-Labs/jaseci.git
cd jaseci
```

This will install all development dependencies, including testing and linting tools.

</details>

## Command-Line Interface (CLI)

The `jac` CLI is your primary interface for interacting with the Jaseci ecosystem.

| Command | Description |
| :--- | :--- |
| **`jac run <file.jac>`** | Executes a Jac file, much like `python3`. |
| **`jac build <file.jac>`** | Builds a self-contained Jac application from a source file. |
| **`jac start <file.jac>`** | Starts a REST API server for a Jac program. |

---

## Awesome Jaseci Projects

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

---

## Join the Community & Contribute

We are building the future of AI development, and we welcome all contributors.

- **`` Join our Discord:** The best place to ask questions, share ideas, and collaborate is our [**Discord Server**](https://discord.gg/6j3QNdtcN6).
- **`` Report Bugs:** Find a bug? Please create an issue in this repository with a clear description.
- **`` Submit PRs:** Check out our [**Contributing Guide**](https://www.jac-lang.org/internals/contrib/) for details on our development process.

<br>

## License

All Jaseci open source software is distributed under the terms of both the MIT license with a few other open source projects vendored
within with various other licenses that are very permissive.

See [LICENSE-MIT](.github/LICENSE) for details.
