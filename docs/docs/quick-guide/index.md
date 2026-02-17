# Welcome to Jac

**One Language for AI-Native Full-Stack Development**

Jac is a programming language that supersets Python and JavaScript with native compilation support, adding novel constructs for AI-integrated programming. Access the entire PyPI and npm ecosystems while using features like `by llm()` to seamlessly weave AI into your code. Write backend logic, frontend interfaces, and AI integrations in a single unified language.

---

## Why Jac?

| What You Want | How Jac Helps |
|---------------|---------------|
| **Build AI apps easily** | Native LLM integration with `by llm()` - no prompt engineering |
| **Full-stack in one language** | React-style frontend + Python backend, seamlessly connected |
| **Use existing libraries** | Full access to PyPI and npm ecosystems |
| **Deploy without DevOps** | `jac start --scale` deploys to Kubernetes automatically |
| **Model complex domains** | Graph-based Object-Spatial Programming for connected data |
| **Code with AI assistance** | Clean syntax designed for both humans and AI models to read and write |

!!! example "See it in action"
    Want to see exactly how much code Jac eliminates? Check out [Jac vs Traditional Stack](jac-vs-traditional-stack.md) - a side-by-side comparison showing **~30 lines of Jac** vs **>300 lines** of Python + FastAPI + SQLite + TypeScript + React for the same Todo app.

---

## Get Started in 5 Minutes

### Step 1: Install

```bash
pip install jaseci
```

This installs the complete Jac ecosystem: `jaclang` (compiler), `byllm` (AI integration), `jac-client` (frontend), `jac-scale` (deployment), and `jac-super` (enhanced console).

Verify your installation:

```bash
jac --version
```

This also warms the cache, making subsequent commands faster.

### Step 2: Create Your First Program

Create `hello.jac`:

```jac
with entry {
    print("Hello from Jac!");
}
```

### Step 3: Run It

```bash
jac hello.jac
```

Note: `jac` is shorthand for `jac run` - both work identically.

**That's it!** You just ran your first Jac program.

---

## Choose Your Path

<div class="grid cards" markdown>

- :material-rocket-launch:{ .lg .middle } **Just want to try it?**

    ---

    Follow the [Hello World](hello-world.md) guide to write your first program in 2 minutes.

- :material-web:{ .lg .middle } **Building a web app?**

    ---

    Jump to [Build Your First App](../tutorials/first-app/part1-todo-app.md) - build a complete app with a 3-part tutorial.

- :material-robot:{ .lg .middle } **Working with AI/LLMs?**

    ---

    See the [AI Integration tutorial](../tutorials/ai/quickstart.md) for byLLM basics, or try [Part 2: Add AI](../tutorials/first-app/part2-ai-features.md) in the first app tutorial.

- :material-book-open-variant:{ .lg .middle } **Want the full picture?**

    ---

    Read [Next Steps](next-steps.md) for learning paths by experience level.

</div>

---

## Core Principles

Jac is built on six key principles:

1. **AI-Native** - LLMs as first-class types via [Meaning Typed Programming](https://arxiv.org/pdf/2405.08965). Call AI like a function.

2. **Full-Stack in One Language** - Write React components alongside server code. No context switching.

3. **Supersets Python & JavaScript** - Use `numpy`, `pandas`, `react`, `tailwind` directly. Your existing knowledge applies.

4. **Object-Spatial Programming** - Model domains as graphs. Deploy walkers to traverse and transform data.

5. **Cloud-Native** - One command to production: `jac start --scale` handles Kubernetes, Redis, MongoDB.

6. **Human + AI Readable** - Clean syntax that both developers and AI models can read and write effectively.

---

## Who is Jac For?

Jac is designed for developers who want to build AI-powered applications without the complexity of managing multiple languages and tools.

| You Are | Jac Gives You |
|---------|---------------|
| **Startup Founder** | Build and ship complete products faster with one language |
| **AI/ML Engineer** | Native LLM integration without prompt engineering overhead |
| **Full-Stack Developer** | React frontend + Python backend, no context switching |
| **Python Developer** | Familiar syntax with powerful new capabilities |
| **Frontend Engineer** | Write UI components with full access to npm ecosystem |
| **Student/Learner** | Modern language designed for clarity and simplicity |

!!! note "What You Should Know"
    Jac supersets Python, so **Python familiarity is assumed** throughout these docs. If you plan to use the full-stack features, basic **React/JSX** knowledge helps. No graph database experience is needed -- Jac teaches you that.

---

## When to Use Jac

**Jac excels at:**

- AI-powered applications with LLM integration
- Full-stack web applications (frontend + backend)
- Applications with complex relational data (graphs, networks)
- Rapid prototyping with production scalability
- Projects requiring both Python and JavaScript ecosystems

**Consider alternatives for:**

- Performance-critical systems programming (use Rust, C++)
- Mobile native apps (use Swift, Kotlin)
- Simple scripts where Python suffices

---

## Quick Links

| Resource | Description |
|----------|-------------|
| [Installation](install.md) | Detailed setup with IDE configuration |
| [Hello World](hello-world.md) | Your first Jac program (2 min) |
| [Build Your First App](../tutorials/first-app/part1-todo-app.md) | Complete 3-part tutorial: todo app, AI, walkers |
| [Tutorials](../tutorials/index.md) | In-depth learning paths |
| [Language Reference](../reference/language/index.md) | Complete language documentation |
| [CLI Reference](../reference/cli/index.md) | All `jac` commands |

---

## Need Help?

- **Discord**: Join our [community server](https://discord.gg/6j3QNdtcN6) for questions and discussions
- **GitHub**: Report issues at [Jaseci-Labs/jaseci](https://github.com/Jaseci-Labs/jaseci)
- **JacGPT**: Ask questions at [jac-gpt.jaseci.org](https://jac-gpt.jaseci.org)
