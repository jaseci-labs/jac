# Next Steps

Choose a learning path based on your goals and background.

---

## Learning Paths

### I want to build AI-powered applications

**Path: AI Integration**

1. [byLLM Quickstart](../tutorials/ai/quickstart.md) - Basic LLM integration
2. [Structured Outputs](../tutorials/ai/structured-outputs.md) - Type-safe AI responses
3. [Agentic AI](../tutorials/ai/agentic.md) - Tool calling and ReAct patterns

**Key concept:** The `by llm()` syntax lets you delegate function bodies to AI models with automatic prompt generation from type signatures and docstrings.

```jac
"""Summarize the article in 2-3 sentences."""
def summarize(text: str) -> str by llm();
```

---

### I want to build full-stack web apps

**Path: Full-Stack Development**

1. [Project Setup](../tutorials/fullstack/setup.md) - Create a Jac web project
2. [React-Style Components](../tutorials/fullstack/components.md) - Build UI with JSX
3. [State & Effects](../tutorials/fullstack/state.md) - Reactive state management
4. [Backend Integration](../tutorials/fullstack/backend.md) - Connect frontend to walkers
5. [Authentication](../tutorials/fullstack/auth.md) - Add user login
6. [Routing](../tutorials/fullstack/routing.md) - Multi-page apps

**Key concept:** Write frontend and backend in one file. The `cl { }` block marks client-side code.

```jac
# Backend
walker get_data {
    can fetch with `root entry {
        report {"message": "Hello from backend"};
    }
}

# Frontend
cl {
    def:pub app() -> any {
        data = root spawn get_data();
        return <div>{data}</div>;
    }
}
```

---

### I want to learn the Jac language deeply

**Path: Core Language**

1. [Jac Basics](../tutorials/language/basics.md) - Syntax and fundamentals
2. [Object-Spatial Programming](../tutorials/language/osp.md) - Nodes, edges, walkers
3. [Testing](../tutorials/language/testing.md) - Write and run tests

**Key concept:** Jac is a superset of Python and TypeScript/JavaScript, adding graphs as first-class citizens and walkers for graph traversal.

```jac
node Person { has name: str; }
edge Knows { has since: int; }

walker find_friends {
    can search with Person entry {
        friends = [here ->:Knows:->];
        report friends;
    }
}
```

---

### I want to deploy to production

**Path: Production Deployment**

1. [Local API Server](../tutorials/production/local.md) - Run as HTTP server
2. [Deploy to Kubernetes](../tutorials/production/kubernetes.md) - Scale with jac-scale

**Key concept:** One command transforms your Jac code into a production API with auto-provisioned infrastructure.

```bash
# Local development
jac start app.jac

# Production Kubernetes
jac start app.jac --scale
```

---

## By Background

### Coming from Python

You'll feel at home. Jac is a Python superset.

**What's different:**

- Braces `{ }` instead of indentation
- Semicolons `;` required
- Type annotations encouraged
- New keywords: `node`, `edge`, `walker`, `has`, `can`

**Start here:** [Jac Basics](../tutorials/language/basics.md)

---

### Coming from JavaScript/TypeScript

Jac's frontend syntax will look familiar (JSX-style).

**What's familiar:**

- Braces and semicolons
- JSX for components
- React-like patterns (useState, useEffect)

**What's different:**

- Python-based syntax for logic
- No `const`/`let` - just variable assignment
- Type annotations use `:` not TypeScript syntax

**Start here:** [Full-Stack Setup](../tutorials/fullstack/setup.md)

---

### Coming from Other Languages

**Key concepts to learn:**

1. **Python ecosystem** - Jac uses Python libraries
2. **Graph thinking** - Model data as nodes and edges
3. **Walker pattern** - Computation that moves through data

**Start here:** [Hello World](hello-world.md) → [Your First Full-Stack AI App](first-fullstack-ai-app.md)

---

## Reference Documentation

When you need details:

| Resource | Use For |
|----------|---------|
| [Language Reference](../reference/language/index.md) | Complete syntax and semantics |
| [CLI Reference](../reference/cli/index.md) | All `jac` commands |
| [Configuration](../reference/config/index.md) | `jac.toml` settings |
| [byLLM Reference](../reference/plugins/byllm.md) | AI integration details |
| [jac-client Reference](../reference/plugins/jac-client.md) | Frontend framework |
| [jac-scale Reference](../reference/plugins/jac-scale.md) | Production deployment |

---

## Examples Gallery

Learn by studying complete applications:

| Example | Description | Difficulty |
|---------|-------------|------------|
| [LittleX](../tutorials/examples/littlex.md) | Twitter clone in 200 lines | Intermediate |
| [EmailBuddy](../tutorials/examples/emailbuddy.md) | AI email assistant | Intermediate |
| [RAG Chatbot](../tutorials/examples/rag-chatbot.md) | Document Q&A with MCP | Advanced |
| [RPG Generator](../tutorials/examples/rpg.md) | AI-generated game levels | Advanced |

---

## Get Help

- **Discord**: [Join our community](https://discord.gg/6j3QNdtcN6) for real-time help
- **JacGPT**: [jac-gpt.jaseci.org](https://jac-gpt.jaseci.org) - AI assistant for Jac questions
- **GitHub Issues**: [Report bugs](https://github.com/Jaseci-Labs/jaseci/issues)
- **Playground**: [Try Jac in browser](https://playground.jaseci.org/cl/app)
