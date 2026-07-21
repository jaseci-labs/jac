# One Binary, Build Anything

Jac ships as a single native binary. One download gives you a complete polyglot development environment -- no system Python, no Node.js, no C toolchain, no package manager to install first. Everything is bundled.

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

That's it. You now have a compiler, a runtime, a package manager, a server, a build system, and a native linker -- all behind one command.

## The toolchain is the hidden tier

The fragmentation that [Why Jac Exists](why-jac.md) counts does not stop at
the program text. The toolchain is a substrate of its own: interpreter,
bundler, compilers, linker, package managers, server, and deployer, each
separately installed and separately versioned. Version skew between them is a
*discontinuity* in time, the same marshaling failure with the filesystem as
the wire format, and "works on my machine" is its error message. The `jac`
binary dissolves this boundary the way the language dissolves the others: by
internalizing the whole toolchain under one content-addressed version. The
version vector of your toolchain collapses to length one.

## One compiler for the whole application: the polypiler

The compiler inside the binary is a *polypiler*: a compiler whose unit of
compilation is the whole polyglot application, whose targets are ecosystems
rather than instruction sets, and whose optimization surface includes the
boundaries between them. One `jac build` sees the server code, the client
code, and the native code as one program: `sv` declarations lower to Python
bytecode among PyPI packages, `cl` declarations lower to JavaScript among npm
packages, and `na` declarations lower through LLVM to machine code beside C
libraries. For example, the HTTP call, serialization, and shared types behind
a client-to-server function call are not written or generated for you to
maintain: they are compiler output, owned and re-derived on every build.

## What's Inside the Binary

| Capability | What it replaces | How you use it |
|---|---|---|
| **CPython 3.14** | System Python, pyenv, venvs | Bundled -- runs your `.jac` files and PyPI imports |
| **Bun** | Node.js, npm, npx | Bundled -- compiles `.cl.jac` to JS, manages npm deps |
| **LLVM + Zig linker** | gcc, clang, make, cmake | Bundled -- `jac build --as native` produces native binaries |
| **Package manager** | pip, npm, pipx | `jac install` for PyPI and npm |
| **REST server** | Flask, FastAPI, Express | `jac start` -- walkers become API endpoints |
| **Kubernetes deployer** | Docker + kubectl + Helm | `jac start --scale` -- one-command K8s deployment |
| **AI integration** | LangChain, prompt libraries | `by llm()` -- built into the language |
| **MCP server** | Separate MCP package | `jac mcp` -- built in, no install needed |
| **Type checker** | mypy, pyright, tsc | `jac check` -- built into the compiler |
| **Formatter & linter** | black, ruff, eslint | `jac fmt`, `jac check --lint` |
| **Test runner** | pytest, jest | `jac test` |
| **Language server** | Separate LSP packages | `jac lsp` -- IDE support built in |

## Two Scopes for Dependencies

Jac has exactly two places dependencies can live. No more "is this in my venv or system Python?" confusion.

### Project scope (default)

Dependencies declared in `jac.toml` and installed into the project's `.jac/venv/`:

```bash
# Add a dependency to your project
jac install numpy

# Or declare it in jac.toml and install
jac install
```

```toml
# jac.toml
[dependencies]
numpy = ">=1.26"

[dependencies.npm]
react = "^18.2.0"
```

Both PyPI and npm packages live in the same config file, managed by the same tool.

### Global scope

Python tools you want available everywhere -- not tied to any project:

```bash
jac install --global huggingface_hub
```

Global packages live in the binary's own jac-owned site, accessible from any directory on your machine.

## `jac x` -- The Universal Tool Runner

`jac x` runs any CLI tool installed via `jac install`, whether it came from PyPI or npm. Think of it as `npx` and `pipx run` combined:

```bash
# Install and run Python CLI tools (global -- available anywhere)
jac install --global huggingface_hub
jac x hf whoami          # runs the Hugging Face CLI

# Project-scoped Python tools work too
jac install ruff         # installed into .jac/venv
jac x ruff check .       # runs ruff within the project

# npm CLI tools are project-scoped
jac install --npm prettier
jac x prettier --check . # runs from the project's node_modules/.bin
```

The tool runs with the correct environment automatically -- no `source .venv/bin/activate`, no `npx`, no `pipx`. Python tools execute in-process under the bundled interpreter; npm tools run through the bundled Bun runtime. Inside a project, a project-installed tool shadows a global one of the same name; a bare `jac x` lists everything runnable. See [`jac x`](../reference/cli/index.md#jac-x) for resolution details.

## What You Can Uninstall

With Jac installed, you no longer need these on your development machine:

| Tool | Why it's replaced |
|---|---|
| Python / pyenv / conda | Jac bundles CPython 3.14 |
| pip / pipx / uv / poetry | `jac install` manages Python deps |
| Node.js / npm / npx / yarn | Jac bundles Bun; `jac install` manages JS deps |
| venv / virtualenv | `.jac/venv` is automatic and project-scoped |
| gcc / clang / make / cmake | Jac bundles LLVM + Zig for native compilation |
| Flask / FastAPI / Express | `jac start` generates a server from your code |

!!! note
    You only need these replacements if you're building with Jac. If you have other Python or Node projects, keep those toolchains installed for them.

## Your App Ships as One Binary Too

The one-binary idea applies to what you build, not just the toolchain. `jac build` type-checks the whole project (fail-closed) and emits a single sealed **`.jab`** app bundle: client dist, serve manifest, and native binaries baked in and hash-verified. Any machine with Jac installed runs or serves it with zero live compilation:

```bash
jac build                  # -> dist/<app>.jab
jac run dist/<app>.jab     # cli kinds execute
jac start dist/<app>.jab   # servable kinds production-serve
```

For machines with nothing installed at all -- no Jac, no Python, no Node -- project the same app to a **self-contained executable**. `jac build --as binary` appends the sealed `.jab` onto a copy of the `jac` launcher, producing one file that carries the full runtime:

```bash
jac build --as binary      # -> one executable, full runtime included
```

And when your program fits the restricted `na` subset, `jac build --as native` compiles it through LLVM into a small, dependency-free binary instead. See [`jac build`](../reference/cli/index.md#jac-build) for all artifact projections and the binary-vs-native trade-off.

## How It Works

The Jac binary is a self-contained native executable that embeds:

- A **CPython 3.14 runtime** (stripped of unnecessary components)
- A **Bun runtime** for JavaScript/TypeScript compilation
- An **LLVM backend** for native code generation
- A **Zig-based linker** for producing native binaries and shared libraries
- The **Jac compiler**, type checker, formatter, and all language tooling
- Built-in subsystems: **byLLM** (AI), **Scale** (deployment), **Client** (full-stack), **MCP** (AI assistant integration)

On the first launch of a freshly installed binary, it unpacks its runtime into a per-version cache -- you'll see a brief one-time setup notice; every run after that is instant.

When you run `jac install`, dependencies are resolved from PyPI or npm into an isolated environment (`.jac/venv` for projects, a jac-owned global site for `--global`). The Jac binary provides the runtime; dependencies provide the libraries. The built-in subsystems ship with the binary itself, so only their optional third-party dependencies (litellm for byLLM, pymongo for scale, ...) are ever installed -- declare the matching config in `jac.toml` and `jac install` resolves them.

## Quick Start

```bash
# Install Jac (one self-contained binary)
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash

# Verify
jac --version

# Create a project
jac create my-app --kind web-app
cd my-app
jac install
jac start

# Open http://localhost:8000
```

From zero to a running full-stack app with graph persistence and auto-generated API docs -- using one tool. To add AI, declare a model under `[byllm]` in `jac.toml` and run `jac install` to pull byLLM's optional dependencies; then `by llm()` works in your code.
