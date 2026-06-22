# Jaseci

### Complete AI-Native Programming Ecosystem

Jaseci is the complete AI-native programming ecosystem built around the Jac language.

## What's Included

- **jaclang** - The Jac programming language, including the built-in full-stack web and native-desktop app framework (React-like `cl` components, server, and bundler). Distributed as the self-contained `jac` binary.
- **byllm** - LLM integration for AI-native programming
- **jac-scale** - Scalable cloud/runtime services for Jac
- **jac-mcp** - MCP server for AI-assisted Jac development

## Installation

Install the `jac` binary (the language core) -- no Python, pip, or uv required:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

Then add the plugins you need:

```bash
jac install byllm jac-scale jac-mcp
```

> **Note:** `jaclang` is no longer published to PyPI -- it ships only as the `jac` binary, which provides the runtime that the plugins build on. Install plugins individually with `jac install` rather than a bundled meta-package.

## Quick Start

After installation, you can start using Jac:

```bash
jac --help
```

## Documentation

- **Jac Language**: [https://www.jac-lang.org](https://www.jac-lang.org)
- **byLLM (AI Integration)**: [https://www.byllm.ai](https://www.byllm.ai)
- **Jac Client**: [https://docs.jaseci.org/jac-client/](https://docs.jaseci.org/jac-client/)
- **Jaseci Homepage**: [https://jaseci.org](https://jaseci.org)
- **GitHub Repository**: [https://github.com/Jaseci-Labs/jaseci](https://github.com/Jaseci-Labs/jaseci)
