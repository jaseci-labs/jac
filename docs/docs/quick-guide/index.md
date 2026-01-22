# Welcome to Jac

**One Language for AI-Native Full-Stack Development**

Jac is a programming language that extends Python with powerful capabilities for building modern AI-powered applications. Write backend logic, frontend interfaces, and AI integrations in a single unified language.

---

## Why Jac?

| What You Want | How Jac Helps |
|---------------|---------------|
| **Build AI apps easily** | Native LLM integration with `by llm()` - no prompt engineering |
| **Full-stack in one language** | React-style frontend + Python backend, seamlessly connected |
| **Use existing libraries** | Full access to PyPI and npm ecosystems |
| **Deploy without DevOps** | `jac start --scale` deploys to Kubernetes automatically |
| **Model complex domains** | Graph-based Object-Spatial Programming for connected data |

---

## Get Started in 5 Minutes

### Step 1: Install

```bash
pip install jaseci
```

### Step 2: Create Your First Program

Create `hello.jac`:

```jac
with entry {
    print("Hello from Jac!");
}
```

### Step 3: Run It

```bash
jac run hello.jac
```

**That's it!** You just ran your first Jac program.

---

## Choose Your Path

<div class="grid cards" markdown>

- :material-rocket-launch:{ .lg .middle } **Just want to try it?**

    ---

    Follow the [Hello World](hello-world.md) guide to write your first program in 2 minutes.

- :material-web:{ .lg .middle } **Building a web app?**

    ---

    Jump to [Your First App](first-app.md) to build a full-stack todo app.

- :material-robot:{ .lg .middle } **Working with AI/LLMs?**

    ---

    See the [AI Integration tutorial](../tutorials/ai/quickstart.md) for byLLM basics.

- :material-book-open-variant:{ .lg .middle } **Want the full picture?**

    ---

    Read [Next Steps](next-steps.md) for learning paths by experience level.

</div>

---

## Core Principles

Jac is built on six key principles:

1. **AI-Native** - LLMs as first-class types via [Meaning Typed Programming](https://arxiv.org/pdf/2405.08965). Call AI like a function.

2. **Full-Stack in One Language** - Write React components alongside server code. No context switching.

3. **Python & JavaScript Superset** - Use `numpy`, `pandas`, `react`, `tailwind` directly. Your existing knowledge applies.

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
| [Hello World](hello-world.md) | Your first Jac program |
| [First App](first-app.md) | Build a complete application |
| [Tutorials](../tutorials/index.md) | In-depth learning paths |
| [Language Reference](../reference/language/index.md) | Complete language documentation |
| [CLI Reference](../reference/cli/index.md) | All `jac` commands |

---

## Need Help?

- **Discord**: Join our [community server](https://discord.gg/6j3QNdtcN6) for questions and discussions
- **GitHub**: Report issues at [Jaseci-Labs/jaseci](https://github.com/Jaseci-Labs/jaseci)
- **JacGPT**: Ask questions at [jac-gpt.jaseci.org](https://jac-gpt.jaseci.org)
