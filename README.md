<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/docs/assets/logo.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/docs/assets/logo.png">
    <img alt="Jaclang logo" src="docs/docs/assets/logo.png" width="80px">
  </picture>

  <h1>Jaseci</h1>
  <h3>One Language for AI-Native Full-Stack Development</h3>

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

Jaseci serves as the implementation stack for the Jac programming language. As a superset of both Python and TypeScript/JavaScript, Jac provides seamless access to the entire PyPI and npm ecosystems, enabling developers to build complete applications, from backend logic to frontend interfaces, in a single unified language.

The project brings together a set of components that work seamlessly together:

- **[`jaclang`](jac/):** The Jac programming language, a drop‑in replacement for and superset of both Python and Typescript/Javascript. (`pip install jaclang`)
- **[`byllm`](jac-byllm/):** Plugin for Jac enabling easy integration of large language models into your applications through the innovative [Meaning Typed Programming](https://arxiv.org/pdf/2405.08965) concept. (`pip install byllm`)
- **[`jac-client`](jac-client/):** Plugin for Jac to bundle full-stack web applications with full access to the entire npm/node package ecosystem. (`pip install jac-client`)
- **[`jac-scale`](jac-scale/):** Plugin for Jac enabling fully abstracted and automated deployment and scaling with FastAPI, Redis, MongoDB, and Kubernetes integration. (`pip install jac-scale`)
- **[`jac-super`](jac-super/):** Plugin for Jac providing enhanced console output with Rich formatting. (`pip install jac-super`)
- **[`jac VSCE`](https://github.com/jaseci-labs/jac-vscode/blob/main/README.md):** The official VS Code extension for Jac.

All of these components are bundled together as the [**Jaseci**](jaseci-package/) stack, which can be installed with a simple `pip install jaseci`.

---

## Core Concepts

Jac is an innovative programming language that extends both Python and TypeScript/JavaScript while maintaining full interoperability with both ecosystems. It introduces cutting-edge programming models and abstractions specifically designed to hide complexity, embrace AI-forward development, and automate categories of common software systems that typically require manual implementation. Despite being relatively new, Jac has already proven its production-grade capabilities, currently powering several real-world applications across various use cases. Jaseci's power is rooted in five key principles.

- **AI-Native:** Treat AI models as a native type through [Meaning Typed Programming](https://arxiv.org/pdf/2405.08965). Weave LLMs into your logic as effortlessly as calling a function, no prompt engineering required.

- **Full-Stack in One Language:** Build complete applications, backend logic and frontend interfaces, in a single language. Write React-like components alongside your server code with seamless data flow between them.

- **Python & JavaScript Superset:** Access the entire PyPI ecosystem (`numpy`, `pandas`, `torch`, etc.) and npm ecosystem (`react`, `vite`, `tailwind`, etc.) without friction. All valid Python and JavaScript code can be expressed in Jac code.

- **Agentic Object Spatial Programming Model:** The next evolution beyond objects and types, is representing them in a graph. Model your domain as a first-class graph of objects and deploy agentic **walker** objects to travel through your object graph performing operations in-situ. Intuitively model AI state, the problem domain, and data.

- **Cloud-Native:** Deploy your application as a production-ready API server with a single `jac start` command. Scale automatically to Kubernetes with `jac start --scale`, zero code changes required.

- **Designed for Humans and AI Models to Use:** A language built to maximize readability, architectural clarity, and coding joy for human developers while enabling AI models to generate high-quality code at scale. Features like `has` declarations for clean attribute definitions and `impl` separation (interfaces separate from implementations) create a structure that both humans can easily reason about and models can reliably produce.

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
git clone --recurse --depth 1 --single-branch https://github.com/jaseci-labs/jaseci
cd jaseci
```

This will install all development dependencies, including testing and linting tools.

</details>

## Command-Line Interface (CLI)

The `jac` CLI is your primary interface for interacting with the Jaseci ecosystem.

| Command | Description |
| :--- | :--- |
| **`jac run <file.jac>`** | Executes a Jac file, much like `python3`. |
| **`jac start <file.jac>`** | Starts a REST API server for a Jac program. |
| **`jac start <file.jac> --scale`** | Deploys to Kubernetes with Redis and MongoDB auto-provisioning. |
| **`jac create --use client <name>`** | Creates a new full-stack Jac project with frontend support. |
| **`jac plugins`** | Manages Jac plugins (enable/disable jac-scale, jac-client, etc.). |

---

## Awesome Jaseci Projects

Explore these impressive projects built with Jaseci! These innovative applications showcase the power and versatility of the Jaseci ecosystem. Consider supporting these projects or getting inspired to build your own.

| Project | Description | Link |
|---------|-------------|------|
| **Tobu** | Your AI-powered memory keeper that captures the stories behind your photos and videos | [Website](https://tobu.life/) |
| **TrueSelph** | A Platform Built on Jivas for building Production-grade Scalable Agentic Conversational AI solutions | [Website](https://trueselph.com/) |
| **Myca** | An AI-powered productivity tool designed for high-performing individuals | [Website](https://www.myca.ai/) |
| **Pocketnest Birdy AI** | A Commercial Financial AI Empowered by Your Own Financial Journey | [Website](https://www.pocketnest.com/) |

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
