<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/docs/assets/logo.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/docs/assets/logo.png">
    <img alt="Jaclang logo" src="docs/docs/assets/logo.png" width="80px">
  </picture>

  <h1>Jaseci</h1>
  <h3>Designed for Humans and AI to Build Together</h3>

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

Jac is a programming language designed for humans and AI to build together. It supersets Python and JavaScript with native compilation support, adding constructs that let you weave AI into your code, model complex domains as graphs, and deploy to the cloud -- all without switching languages, managing databases, or writing infrastructure.

This repository houses the Jaseci stack -- the core libraries and tooling that make Jac work:

- **[`jaclang`](jac/):** The Jac programming language -- supersets Python and JavaScript with native compilation support. (`pip install jaclang`)
- **[`byllm`](jac-byllm/):** Plugin for Jac enabling easy integration of large language models into your applications through the innovative [Meaning Typed Programming](https://arxiv.org/pdf/2405.08965) concept. (`pip install byllm`)
- **[`jac-client`](jac-client/):** Plugin for Jac to bundle full-stack web applications with full access to the entire npm/node package ecosystem. (`pip install jac-client`)
- **[`jac-scale`](jac-scale/):** Plugin for Jac enabling fully abstracted and automated deployment and scaling with FastAPI, Redis, MongoDB, and Kubernetes integration. (`pip install jac-scale`)
- **[`jac-super`](jac-super/):** Plugin for Jac providing enhanced console output with Rich formatting. (`pip install jac-super`)
- **[`jac VSCE`](https://github.com/jaseci-labs/jac-vscode/blob/main/README.md):** The official VS Code extension for Jac.

All of these components are bundled together as the [**Jaseci**](jaseci-package/) stack, which can be installed with a simple `pip install jaseci`.

---

## Core Concepts

Jac imagines what should be abstracted away from the developer and automates it through the compiler and runtime. This philosophy is grounded in five key principles.

- **AI-Native:** Treat AI models as a native type through [Meaning Typed Programming](https://arxiv.org/pdf/2405.08965). Weave LLMs into your logic as effortlessly as calling a function, no prompt engineering required.

- **Full-Stack in One Language:** Build backend logic and frontend interfaces without switching languages. Write React-like components alongside your server code with seamless data flow between them.

- **Python & JavaScript Superset:** Supersets both Python and JavaScript with native compilation support. Access the entire PyPI ecosystem (`numpy`, `pandas`, `torch`, etc.) and npm ecosystem (`react`, `vite`, `tailwind`, etc.) without friction.

- **Graph-Native Domain Modeling:** Model complex domains as first-class graphs of objects and deploy agentic **walker** objects to traverse them, performing operations in-situ. No separate database setup or ORM required.

- **Cloud-Native:** Deploy to the cloud without writing infrastructure. A single `jac start` command gives you a production-ready API server. Add `--scale` for automatic Kubernetes deployment with Redis and MongoDB provisioning.

- **Designed for Humans and AI:** A language built for human readability and AI code generation alike. The number of tokens to realize a full application is minimized by ~10x on average, and features like `has` declarations and `impl` separation (interfaces separate from implementations) create structure that both humans can reason about and models can reliably produce.

---

## A Complete Full-Stack AI App in One File

```jac
node Todo {
    has title: str, done: bool = False;
}

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

def categorize(title: str) -> Category
    by llm();

def:pub get_todos -> list {
    if not [root-->](?:Todo) {
        root ++> Todo(title="Buy groceries");
        root ++> Todo(title="Finish report");
    }
    return [{"title": t.title, "category": str(categorize(t.title)).split(".")[-1]}
            for t in [root-->](?:Todo)];
}

cl def:pub app() -> JsxElement {
    has items: list = [];
    async can with entry { items = await get_todos(); }
    return <div>{[<p key={i.title}>{i.title} ({i.category})</p>
                  for i in items]}</div>;
}
```

This single file defines a persistent data model, an AI-powered categorizer, a REST API, and a React frontend -- without any database configuration, prompt engineering, or separate frontend project.

<details>
<summary><strong>Run this example</strong></summary>

<br>

Save the code above as `main.jac`, then create a `jac.toml` in the same directory:

```toml
[project]
name = "my-app"

[dependencies.npm]
jac-client-node = "1.0.4"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "1.0.0"

[serve]
base_route_app = "app"

[plugins.client]

[plugins.byllm.model]
default_model = "claude-sonnet-4-20250514"
```

Install Jac, set your API key, and run:

```bash
pip install jaseci
export ANTHROPIC_API_KEY="your-key-here"
jac start main.jac
```

Open [http://localhost:8000](http://localhost:8000) to see it running. Jac supports any [LiteLLM-compatible model](https://docs.litellm.ai/docs/providers) -- use `gemini/gemini-2.5-flash` for a free alternative or `ollama/llama3.2:1b` for local models.

</details>

---

## Become a Jac Programmer

The best way to learn Jac is by building something real. The [**Build an AI Day Planner**](https://docs.jaseci.org/tutorials/first-app/build-ai-day-planner/) tutorial walks you through every core concept -- variables, functions, graphs, walkers, AI integration, authentication, and full-stack deployment -- in a single guided project.

---

## Installation & Setup

<details>
<summary><strong>Install from PyPI (Recommended)</strong></summary>

<br>

Get the complete, stable toolkit from PyPI:

```bash
pip install jaseci
```

The `jaseci` package is a meta-package that bundles `jaclang`, `byllm`, `jac-client`, `jac-scale`, and `jac-super` together for convenience. This is the fastest way to get started with building applications.

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
