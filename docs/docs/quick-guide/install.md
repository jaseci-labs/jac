# Installation

Get Jac installed and ready to use in under 2 minutes.

---

## Requirements

- **Python 3.12+** (check with `python --version`)

---

## Quick Install

```bash
pip install jaseci
```

The `jaseci` package is a meta-package that bundles all Jac ecosystem packages together. This installs:

- `jaclang` - The Jac language and compiler
- `byllm` - AI/LLM integration
- `jac-client` - Full-stack web development
- `jac-scale` - Production deployment
- `jac-super` - Enhanced console output

Verify the installation:

```bash
jac --version
```

This also warms the cache, making subsequent commands faster.

---

## Installation Options

### Minimal Install (Language Only)

If you only need the core language:

```bash
pip install jaclang
```

### Individual Plugins

Install plugins as needed:

```bash
# AI/LLM integration
pip install byllm

# Full-stack web development
pip install jac-client

# Production deployment & scaling
pip install jac-scale

# Enhanced console output
pip install jac-super
```

### Virtual Environment (Recommended)

```bash
# Create environment
python -m venv jac-env

# Activate it
source jac-env/bin/activate   # Linux/Mac
jac-env\Scripts\activate      # Windows

# Install Jac
pip install jaseci
```

---

## IDE Setup

### VS Code (Recommended)

Install the official Jac extension for the best development experience:

**Option 1: From Marketplace**

1. Open VS Code
2. Click Extensions in the sidebar (or press `Ctrl+Shift+X` / `Cmd+Shift+X`)
3. Search for **"Jac"**
4. Click **Install** on "Jac Language Support" by Jaseci Labs

Or install directly: [Open in VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jaclang-extension)

**Option 2: Quick Install**

Press `Ctrl+P` / `Cmd+P` and paste:

```
ext install jaseci-labs.jaclang-extension
```

**Features:**

- Syntax highlighting for `.jac` files
- Intelligent autocomplete
- Real-time error detection
- Hover documentation
- Go to definition
- Graph visualization

### Cursor

1. Download the latest `.vsix` from [GitHub releases](https://github.com/Jaseci-Labs/jac-vscode/releases/latest)
2. Press `Ctrl+Shift+P` / `Cmd+Shift+P`
3. Select "Extensions: Install from VSIX"
4. Choose the downloaded file

---

## Verify Installation

```bash
jac --version
```

Expected output:

```
   _
  (_) __ _  ___     Jac Language
  | |/ _` |/ __|
  | | (_| | (__     Version:  0.X.X
 _/ |\__,_|\___|    Python 3.12.3
|__/                Platform: Linux x86_64

📚 Documentation: https://docs.jaseci.org
💬 Community:     https://discord.gg/6j3QNdtcN6
🐛 Issues:        https://github.com/Jaseci-Labs/jaseci/issues
```

---

## Upgrading Jac

When upgrading to a new version of Jaseci packages, clear the bytecode cache to avoid compatibility issues:

```bash
# Upgrade packages
pip install --upgrade jaseci

# Clear the global bytecode cache
jac purge
```

> **⚠️ Important:** After upgrading, always run `jac purge` to clear stale bytecode. Skipping this step can cause errors like "No module named 'jaclang.pycore'", "NodeAnchor is not a valid reference", or the setup hanging during compilation.

If you encounter issues during first-time setup or after upgrading, `jac purge` is your first troubleshooting step.

---

## For Contributors

See the [Contributing Guide](../community/contributing.md) for development setup.

---

## Next Steps

- [Hello World](hello-world.md) - Write your first program
- [Build Your First App](../tutorials/first-app/part1-todo-app.md) - Build a complete full-stack application
