# Installation and First Run

Get Jac installed and ready to use in under 2 minutes.

---

## One-Line Install (Recommended)

Install Jac with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

This downloads the self-contained native `jac` binary and puts it on your PATH. The binary bundles its own runtime, so **no system Python, pip, or uv is required** -- at install time or afterward.

### Installer Options

Pass flags after `--` to customize the install:

**Specific version:**

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --version 2.3.1
```

**Uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --uninstall
```

| Flag | Description |
|------|-------------|
| `--version V` | Install a specific release version |
| `--uninstall` | Remove Jac |

### Upgrading

Re-run the install command to upgrade to the latest version. The installer replaces the binary in place.

---

## Installing Plugins

The `jac` binary is the language core, and bundles the AI (byLLM), MCP, and deployment & scaling subsystems built in. "Enabling" one of these just resolves its optional dependencies into your project; genuine third-party plugins install the same way, by name:

```bash
# AI/LLM integration (byLLM is built in; this pulls its optional deps -- litellm, pillow, ...):
jac install byllm

# The MCP server and the production deployment & scaling subsystem ship built
# into the jac binary (no install): run `jac mcp`, and use `jac start` /
# `jac start --scale`. Scale's optional deps install per-project via jac.toml.
```

The MCP server for AI-assisted Jac development is built into the binary -- run `jac mcp` directly, no install needed (see [Agent Skills and MCP](agent-skills-and-mcp.md)).

`jac install` resolves plugins from PyPI into your project environment; jaclang itself is provided by the binary, so it is never reinstalled. See the [CLI reference](../reference/cli/index.md#jac-install) for all options.

!!! note "Deployment & scaling is built in"
    Production serving and Kubernetes deployment (`jac start`, `jac start --scale`) ship inside the `jac` binary as the built-in `scale` subsystem -- there is no separate `jac-scale` package to install. Scale's optional heavier dependencies (MongoDB, Redis, Kubernetes, Prometheus, ...) are pulled into your project on demand: declare the matching `[scale.*]` config in `jac.toml`, then run `jac install` to resolve them into `.jac/venv`.

---

## IDE Setup

The **Jac Language Support** extension is available on both major extension marketplaces:

| Marketplace | Link |
|-------------|------|
| VS Code Marketplace | [jaseci-labs.jaclang-extension](https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jaclang-extension) |
| Open VSX Registry | [jaseci-labs/jaclang-extension](https://open-vsx.org/extension/jaseci-labs/jaclang-extension) |

### Supported IDEs

- [VS Code](https://code.visualstudio.com/)
- [Cursor](https://www.cursor.com/)
- [Windsurf](https://codeium.com/windsurf)
- [Antigravity](https://antigravity.google/)
- [VSCodium](https://vscodium.com/)
- [Gitpod](https://gitpod.io/)
- [Eclipse Theia](https://theia-ide.org/)
- [Void](https://voideditor.com/)

### Install the Extension

In any of the IDEs above, installing is the same:

1. Open the Extensions panel - `Ctrl+Shift+X` / `Cmd+Shift+X`
2. Search **`jaclang`**
3. Click **Install** on "Jac Language Support" by Jaseci Labs

### Manual Install (VSIX)

For IDEs without marketplace access or for offline installs:

1. Download the latest `.vsix` from [GitHub Releases](https://github.com/Jaseci-Labs/jac-vscode/releases/latest)
2. Open the Command Palette - `Ctrl+Shift+P` / `Cmd+Shift+P`
3. Select **"Extensions: Install from VSIX..."**
4. Choose the downloaded file

### Extension Features

- Syntax highlighting for `.jac` files
- Intelligent autocomplete
- Real-time error detection
- Hover documentation
- Go to definition
- Graph visualization

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

The full-stack client framework ships with `jaclang` core, so you can scaffold a complete full-stack project in one command:

```bash
jac create example --use web-app
cd example
jac install
jac start
```

!!! note
    `main.jac` is the default entry point. All `jac start` commands in this guide omit the filename. If your entry point has a different name (e.g., `app.jac`), pass it explicitly: `jac start app.jac`.

This creates a project with a Jac backend and a React frontend, ready to go at `http://localhost:8000`.

---

## Community Jacpacks

[Jacpacks](https://github.com/jaseci-labs/jacpacks) are ready-made Jac project templates you can spin up instantly. Since `--use` accepts a URL, you can run any jacpack directly from GitHub:

```bash
jac create my-todo --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/multi-user-todo-app/multi-user-todo-app.jacpack
cd my-todo
jac install
jac start
```

Want to try one with AI built in? The `multi-user-todo-meals-app` uses Jac's AI integration features to generate smart shopping lists with costs and nutritional info. It works out of the box with an Anthropic API key:

```bash
export ANTHROPIC_API_KEY="your-key-here"
jac create meals-app --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/multi-user-todo-meals-app/multi-user-todo-meals-app.jacpack
cd meals-app
jac install
jac start
```

To use any of the other jacpacks, just swap the URL:

```bash
jac create my-app --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/<jacpack-name>/<jacpack-name>.jacpack
```

---

## Upgrading Jac

Re-run the one-line installer to upgrade the `jac` binary to the latest version:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

Built-in subsystems (byLLM, MCP, scale) upgrade with the binary itself. To force-refresh a third-party plugin's resolved dependencies, reinstall it:

```bash
jac install --force-reinstall <plugin>
```

---

## Creating a Project

Use `jac create` to scaffold a new project:

```bash
# Client-only web app (no backend, runs in the browser)
jac create my-app --use web-static

# Start the development server
cd my-app
jac start
```

The `--use web-static` template sets up a complete project with:

- `main.jac` -- Entry point with client code
- `jac.toml` -- Project configuration
- `styles.css` -- Default stylesheet
- Bundled frontend dependencies (via Bun)

Available templates:

| Template | Command | What It Creates |
|----------|---------|-----------------|
| Web app | `--use web-app` | Full-stack web app with frontend and backend |
| Web static | `--use web-static` | Client-only app that runs in the browser (no backend) |

You can also use community templates (Jacpacks):

```bash
jac create my-app --use <github-url>
```

---

## For Contributors

Building Jac from source uses `./scripts/fresh_env.sh`, which builds the `jac` binary and puts it on your PATH. See the [Contributing Guide](../community/contributing.md) for the full development setup.

---

## Next Steps

- [Core Concepts](what-makes-jac-different.md) - Codespaces, OSP, and compiler-integrated AI
- [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md) - Build a complete full-stack application
