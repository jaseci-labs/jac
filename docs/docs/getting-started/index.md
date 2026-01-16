# Getting Started with Jac

Welcome to Jac - a programming language designed for the AI era. Jac extends Python with powerful new paradigms while maintaining full compatibility with the Python ecosystem.

## What is Jac?

Jac is a **Python superset** designed for the AI era, introducing three key innovations:

1. **One Language for Full-Stack**: Build complete web applications - React-style frontends and Python-powered backends - in a single language with seamless integration
2. **AI-First Design**: Native LLM integration via the `by llm()` syntax - no prompt engineering required
3. **Scale-Native Execution**: Write once, run anywhere - from local development to cloud deployment without code changes

Jac also introduces **new abstractions** like Object-Spatial Programming (OSP) for working with graph-based data structures using nodes, edges, and walkers as first-class language constructs.

## Quick Start

### 1. Install Jac

```bash
# Create a virtual environment (recommended)
python -m venv jac-env
source jac-env/bin/activate  # Linux/Mac
# jac-env\Scripts\activate   # Windows

# Install Jac
pip install jaclang

# Verify installation
jac --version
```

### 2. Install the VS Code Extension

For the best development experience with syntax highlighting, autocomplete, error detection, and graph visualizations:

**VS Code:** Open Extensions (`Ctrl+Shift+X`), search "Jac", and install the [official Jac extension](https://marketplace.visualstudio.com/items?itemName=jaseci-labs.jaclang-extension).

**Cursor:** Download the latest `.vsix` from [GitHub releases](https://github.com/Jaseci-Labs/jaseci/releases/latest), then use `Ctrl+Shift+P` → "Install from VSIX".

### 3. Hello World

Create a file named `hello.jac`:

```jac
with entry {
    print("Hello, Jac World!");
}
```

Run it:

```bash
jac run hello.jac
```

Output:

```
Hello, Jac World!
```

### 4. Create a Project

Create a full-stack project with frontend and backend:

```bash
# Create a new project with client-side support
jac create --cl myapp
cd myapp

# Start the development server (uses main.jac by default)
# If main.jac doesn't exist, specify your entry file: jac start app.jac --watch
jac start --watch
```

Open `http://localhost:8000` to see your app running. The `--watch` flag enables Hot Module Replacement - edit your code and see changes instantly!

> **Note**: If your project uses a different entry file (e.g., `app.jac`), you can specify it: `jac start app.jac --watch`.

Your project includes:

- `main.jac` - Your application code (frontend + backend in one file)
- `jac.toml` - Project configuration
- Ready-to-use React-style components with JSX syntax

---

## Choose Your Path

Jac supports multiple development styles. Choose the path that fits your project:

### 🖥️ CLI & Scripts

Build command-line tools, automation scripts, and backend services.

```bash
jac run myapp.jac
```

**Next:** [Syntax & Basics](../language/syntax/index.md) → [Object-Spatial Programming](../language/osp/index.md)

---

### 🌐 Full-Stack Web Apps

!!! tip "Most Popular Starting Point"
    Build complete web applications with React-like frontends and Jac backends - **one language for everything**.

```bash
# Create a full-stack project
jac create --cl myapp
cd myapp

# Start development server with hot reload
jac start --watch
```

Open `http://localhost:8000` to see your app. Edit `main.jac` and watch it update instantly!

**Key Features:**

- `cl { }` blocks for React-style components with JSX
- `has` variables automatically become reactive state
- `root spawn MyWalker()` calls backend directly - no fetch() boilerplate
- Hot Module Replacement (HMR) for instant feedback

**Next:** [Full-Stack Guide](../full-stack/index.md)

---

### 🤖 AI Integration

Build LLM-powered applications with native AI syntax - no prompt engineering required.

```jac
import from jac_cloud.core.llm { llm }

can summarize(text: str) -> str by llm();

with entry {
    summary = summarize("Long article text here...");
    print(summary);
}
```

**Next:** [AI Integration Guide](../ai-integration/index.md)

---

### 🚀 Production Deployment

Deploy to Kubernetes with zero configuration changes.

```bash
# Deploy to Kubernetes
jac start myapp.jac --scale

# Remove deployment
jac destroy myapp.jac
```

**Next:** [Production Guide](../production/index.md)

---

## Learn More

| Resource | Description |
|----------|-------------|
| [Installation Guide](../learn/installation.md) | Detailed setup with IDE configuration |
| [Introduction to Jac](../learn/tour.md) | Core concepts and philosophy |
| [Quickstart Tutorial](../learn/quickstart.md) | Build a complete application |
| [The Jac Book](../jac_book/index.md) | Comprehensive learning resource |

## Who is Jac For?

- **Startups**: Rapid prototyping with one language for frontend, backend, and AI
- **AI/ML Engineers**: Build LLM agents and agentic workflows naturally
- **Full-Stack Developers**: Modern language features with Python ecosystem access
- **Students**: Approachable on-ramp to AI development

## When to Use Jac

Jac excels when:

- Your problem domain involves **connected data** (social networks, knowledge graphs)
- You need **LLMs deeply integrated** into your application logic
- You want to **reduce DevOps overhead** with auto-generated APIs
- You prefer **cleaner syntax** with mandatory typing and modern features
