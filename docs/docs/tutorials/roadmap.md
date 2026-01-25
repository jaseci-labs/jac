# Learning Roadmap

Choose your learning path based on your goals. Each path builds on the previous one.

---

## Quick Start (30 minutes)

Start here regardless of your goal:

| Step | Tutorial | Time | What You'll Learn |
|------|----------|------|-------------------|
| 1 | [Installation](../quick-guide/install.md) | 5 min | Install Jac and plugins |
| 2 | [Hello World](../quick-guide/hello-world.md) | 5 min | Basic syntax, functions |
| 3 | [Your First Graph](../quick-guide/first-graph.md) | 10 min | Nodes, edges, walkers |
| 4 | [Your First App](../quick-guide/first-app.md) | 10 min | Complete todo app |

After Quick Start, choose your path:

---

## Path A: Core Language (1 hour)

**Goal:** Master Jac syntax and Object-Spatial Programming

```
Quick Start → Jac Basics → OSP Tutorial → Testing
```

| Step | Tutorial | Time | What You'll Learn |
|------|----------|------|-------------------|
| 5 | [Jac Basics](language/basics.md) | 20 min | Variables, functions, objects |
| 6 | [Object-Spatial Programming](language/osp.md) | 30 min | Nodes, edges, walkers in depth |
| 7 | [Testing](language/testing.md) | 10 min | Write and run tests |

**You can now:** Write Jac programs, build graph-based applications, test your code.

---

## Path B: AI Integration (1 hour)

**Goal:** Build AI-powered applications with LLMs

**Prerequisites:** Quick Start + Path A recommended

```
Quick Start → AI Quickstart → Structured Outputs → Agentic AI
```

| Step | Tutorial | Time | What You'll Learn |
|------|----------|------|-------------------|
| 5 | [byLLM Quickstart](ai/quickstart.md) | 15 min | First AI function |
| 6 | [Structured Outputs](ai/structured-outputs.md) | 20 min | Type-safe LLM responses |
| 7 | [Agentic AI & Tools](ai/agentic.md) | 25 min | Tool calling, ReAct pattern |

**You can now:** Create AI-powered functions, build agentic systems, integrate LLMs.

---

## Path C: Full-Stack Apps (2 hours)

**Goal:** Build complete web applications with frontend and backend

**Prerequisites:** Quick Start + Path A recommended

```
Quick Start → Setup → Components → State → Backend → Auth → Routing
```

| Step | Tutorial | Time | What You'll Learn |
|------|----------|------|-------------------|
| 5 | [Project Setup](fullstack/setup.md) | 15 min | jac-client, project structure |
| 6 | [React-Style Components](fullstack/components.md) | 20 min | JSX in Jac, props |
| 7 | [State & Effects](fullstack/state.md) | 20 min | Reactive state, hooks |
| 8 | [Backend Integration](fullstack/backend.md) | 25 min | Walker APIs, useWalker |
| 9 | [Authentication](fullstack/auth.md) | 20 min | Login, signup, protected routes |
| 10 | [Routing](fullstack/routing.md) | 15 min | Client-side navigation |
| 11 | [Build a Todo App](fullstack/todo-app.md) | 25 min | Complete example with AI |

**You can now:** Build full-stack web apps, handle authentication, manage state.

---

## Path D: Production Deployment (30 minutes)

**Goal:** Deploy Jac applications to production

**Prerequisites:** Quick Start + at least one other path

```
Quick Start → Local Server → Kubernetes
```

| Step | Tutorial | Time | What You'll Learn |
|------|----------|------|-------------------|
| 5 | [Local API Server](production/local.md) | 15 min | jac start, API endpoints |
| 6 | [Deploy to Kubernetes](production/kubernetes.md) | 15 min | jac-scale, K8s deployment |

**You can now:** Run production servers, scale with Kubernetes, deploy to cloud.

---

## Complete Path (4-5 hours)

For comprehensive understanding, follow all paths in order:

```
Quick Start (30 min)
    ↓
Core Language (1 hr)
    ↓
AI Integration (1 hr)
    ↓
Full-Stack Apps (2 hr)
    ↓
Production (30 min)
```

---

## Learning by Example

After completing your chosen path, explore real-world examples:

| Example | Description | Skills Used |
|---------|-------------|-------------|
| [LittleX](examples/littlex.md) | Twitter clone | Full-stack, graph modeling |
| [EmailBuddy](examples/emailbuddy.md) | AI email assistant | AI integration, agentic patterns |
| [RAG Chatbot](examples/rag-chatbot.md) | Document Q&A | AI, vector search |
| [RPG Generator](examples/rpg.md) | Game level generator | Structured outputs, AI |

---

## Quick Reference

Need to look something up? Use the reference docs:

| Topic | Reference |
|-------|-----------|
| Graph operations | [Graph Operations](../reference/language/graph-operations.md) |
| Walker responses | [Walker Responses](../reference/language/walker-responses.md) |
| Full language | [Language Reference](../reference/language/index.md) |
| CLI commands | [CLI Reference](../reference/cli/index.md) |
| Configuration | [Configuration](../reference/config/index.md) |
| byLLM | [byLLM Reference](../reference/plugins/byllm.md) |
| jac-client | [jac-client Reference](../reference/plugins/jac-client.md) |
| jac-scale | [jac-scale Reference](../reference/plugins/jac-scale.md) |

---

## Stuck?

- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Discord](https://discord.gg/jaseci) - Ask the community
- [JacGPT](https://jac-gpt.jaseci.org) - AI-powered help
