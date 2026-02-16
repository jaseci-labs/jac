# Tutorials

In-depth tutorials organized by topic. Each tutorial takes 30-60 minutes to complete.

---

## Start Here

New to Jac? Begin with the **Build Your First App** tutorial -- a 3-part guide that takes you from zero to a multi-user AI-powered app:

| Part | What You'll Build | Concepts |
|------|-------------------|----------|
| [Part 1: Todo App](first-app/part1-todo-app.md) | Working todo app with graph persistence | Nodes, `def:pub`, reactive frontend |
| [Part 2: Add AI](first-app/part2-ai-features.md) | AI categorization + meal planner | `by llm()`, `enum`, `obj`, `sem` |
| [Part 3: Walkers, Auth & Structure](first-app/part3-multi-user.md) | Auth, walkers, multi-file structure | `walker:priv`, authentication, components |

!!! note "First App vs Full-Stack Tutorials"
    **Build Your First App** is a quick end-to-end journey -- build one app across three parts, learning concepts as you go. **Full-Stack Apps** (below) is a deep-dive into each concept individually. New to Jac? Start with Build Your First App. Want to understand a specific topic (routing, state, auth)? Use the Full-Stack tutorials as targeted reference.

---

## Learning Paths

Choose a path based on what you want to build:

### :material-code-braces: Core Language

Master Jac fundamentals and its unique features.

| Tutorial | Description | Time |
|----------|-------------|------|
| [Jac Basics](language/basics.md) | Syntax, types, functions - coming from Python | 30 min |
| [Object-Spatial Programming](language/osp.md) | Nodes, edges, walkers, graph traversal | 45 min |
| [Testing](language/testing.md) | Write and run tests for your code | 20 min |

---

### :material-robot: AI Integration

Build AI-powered applications with byLLM.

| Tutorial | Description | Time |
|----------|-------------|------|
| [byLLM Quickstart](ai/quickstart.md) | First LLM-integrated function | 20 min |
| [Structured Outputs](ai/structured-outputs.md) | Type-safe responses with enums and objects | 30 min |
| [Agentic AI](ai/agentic.md) | Tool calling and ReAct patterns | 45 min |

---

### :material-web: Full-Stack Development

Build complete web applications with jac-client.

| Tutorial | Description | Time |
|----------|-------------|------|
| [Project Setup](fullstack/setup.md) | Create a full-stack Jac project | 15 min |
| [Components](fullstack/components.md) | Build React-style UI components | 30 min |
| [State Management](fullstack/state.md) | Reactive state with hooks | 30 min |
| [Backend Integration](fullstack/backend.md) | Connect frontend to walkers | 30 min |
| [Authentication](fullstack/auth.md) | Add user login and signup | 30 min |
| [Routing](fullstack/routing.md) | Multi-page applications | 20 min |

---

### :material-cloud-upload: Production Deployment

Deploy your applications to production.

| Tutorial | Description | Time |
|----------|-------------|------|
| [Local API Server](production/local.md) | Run as HTTP API with `jac start` | 15 min |
| [Kubernetes Deployment](production/kubernetes.md) | Scale with `jac start --scale` | 30 min |

---

## Examples Gallery

Complete applications to study and learn from.

| Example | Description | Level |
|---------|-------------|-------|
| [LittleX](examples/littlex.md) | Twitter clone in 200 lines | Intermediate |
| [EmailBuddy](examples/emailbuddy.md) | AI email assistant | Intermediate |
| [RAG Chatbot](examples/rag-chatbot.md) | Document Q&A with MCP | Advanced |
| [RPG Generator](examples/rpg.md) | AI-generated game levels | Advanced |

[View all examples →](examples/index.md)

---

## Prerequisites

Before starting tutorials, ensure you have:

- [x] Jac installed (`pip install jaseci`)
- [x] Completed the [Quick Guide](../quick-guide/index.md)
- [x] A code editor (VS Code with Jac extension recommended)

**Assumed knowledge:**

- **Python familiarity required** -- Jac supersets Python; you should be comfortable with functions, classes, and type annotations
- **React/JSX familiarity helpful** -- for full-stack tutorials, basic component and hook knowledge helps
- **Web development basics helpful** -- HTTP, REST, frontend/backend separation

For AI tutorials, you'll also need:

- [x] An LLM API key (OpenAI, Anthropic, or Google)

---

## How to Use These Tutorials

1. **Follow in order** within each path - tutorials build on each other
2. **Type the code** yourself - don't just copy-paste
3. **Experiment** - modify examples to test your understanding
4. **Check the reference** - link to [Language Reference](../reference/language/index.md) for details

---

## Quick Reference Links

| Need | Resource |
|------|----------|
| Syntax lookup | [Language Reference](../reference/language/index.md) |
| CLI commands | [CLI Reference](../reference/cli/index.md) |
| Configuration | [jac.toml Reference](../reference/config/index.md) |
| Get help | [Discord Community](https://discord.gg/6j3QNdtcN6) |
