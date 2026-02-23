# Installation and First Run

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

Run your first program to confirm everything works. Create `hello.jac`:

```jac
with entry {
    print("Hello from Jac!");
}
```

```bash
jac hello.jac
```

You should see `Hello from Jac!` printed to the console.

---

## Scaffold a Full-Stack App

With the `jac-client` plugin installed, scaffold a complete full-stack project in one command:

```bash
jac create example --use fullstack
cd example
jac add
jac start main.jac
```

This creates a project with a Jac backend and a React frontend, ready to go at `http://localhost:8000`.

---

## Community Jacpacks

[Jacpacks](https://github.com/jaseci-labs/jacpacks) are ready-made Jac project templates you can spin up instantly. Since `--use` accepts a URL, you can run any jacpack directly from GitHub:

```bash
jac create my-todo --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/multi-user-todo-app/multi-user-todo-app.jacpack
cd my-todo
jac add
jac start main.jac
```

Want to try one with AI built in? The `multi-user-todo-meals-app` uses Jac's AI integration features to generate smart shopping lists with costs and nutritional info. It works out of the box with an Anthropic API key:

```bash
export ANTHROPIC_API_KEY="your-key-here"
jac create meals-app --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/multi-user-todo-meals-app/multi-user-todo-meals-app.jacpack
cd meals-app
jac add
jac start main.jac
```

To use any of the other jacpacks, just swap the URL:

```bash
jac create my-app --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/<jacpack-name>/<jacpack-name>.jacpack
```

---

## Upgrading Jac

```bash
# Upgrade everything at once
pip install --upgrade jaseci

# Or upgrade individual packages
pip install --upgrade jaclang
pip install --upgrade byllm
pip install --upgrade jac-client
pip install --upgrade jac-scale
pip install --upgrade jac-super
```

---

## Creating a Project

Use `jac create` to scaffold a new project:

```bash
# Full-stack web app (frontend + backend)
jac create my-app --use client

# Start the development server
cd my-app
jac start main.jac
```

The `--use client` template sets up a complete project with:

- `main.jac` -- Entry point with server and client code
- `jac.toml` -- Project configuration
- `styles.css` -- Default stylesheet
- Bundled frontend dependencies (via Bun)

Available templates:

| Template | Command | What It Creates |
|----------|---------|-----------------|
| Client | `--use client` | Full-stack web app with frontend and backend |
| Fullstack | `--use fullstack` | Alias for `--use client` |

You can also use community templates (Jacpacks):

```bash
jac create my-app --use <github-url>
```

---

## For Contributors

See the [Contributing Guide](../community/contributing.md) for development setup.

---

## Next Steps

- [Core Concepts](what-makes-jac-different.md) - Codespaces, OSP, and compiler-integrated AI
- [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md) - Build a complete full-stack application
