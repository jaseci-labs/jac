# Build an AI Day Planner with Jac

In this tutorial, you'll build a full-stack AI day planner from scratch -- a single application that manages daily tasks (auto-categorized by AI) and generates meal shopping lists from natural language descriptions. Each lesson adds one part of the application, with a checkpoint before you continue.

**Prerequisites:** [Installation](../../quick-guide/install.md) complete.

**Required Packages:** This tutorial uses **jaclang** (which bundles the full-stack client framework, the built-in `scale` deployment subsystem, and byLLM for AI). If you installed Jac using the [one-line installer](../../quick-guide/install.md#one-line-install-recommended), the core is already included -- skip to the version check below. Otherwise install the toolchain:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

This installs the self-contained `jac` binary -- no Python, pip, or uv required.

Verify your installation:

```bash
jac --version
```

The `jac --version` output shows the binary version (byLLM, the full-stack client framework, and the `scale` subsystem all ship inside the binary, so there are no separate versions for them):

| Package | Version |
|---------|---------|
| jaclang | Any current release; check with `jac --version` |

**Local AI Model:** Parts 5+ use AI features. The tutorial defaults to a local model -- Google Gemma 4 E4B running in-process via `llama.cpp` -- so **no API key is required**. Install the local-model dependency once:

```bash
jac install 'byllm[local]'
```

The first AI call downloads and caches model weights. Allow disk space and download time; subsequent startup and inference times depend on your hardware and model. If you'd rather use a cloud model (Anthropic Claude, Google Gemini, Ollama, etc.), see the "Use a cloud model instead" callout in [Part 5](day-planner-05-ai.md#part-5-making-it-smart-with-ai).

The tutorial is split into seven parts. Each builds on the last:

| Part | What You'll Build | Key Concepts |
|------|-------------------|--------------|
| [1](day-planner-01-basics.md#part-1-your-first-lines-of-jac) | [Hello World](day-planner-01-basics.md#part-1-your-first-lines-of-jac) | Syntax basics, types, functions |
| [2](day-planner-02-nodes.md#part-2-modeling-data-with-nodes) | [Task data model](day-planner-02-nodes.md#part-2-modeling-data-with-nodes) | Nodes, graphs, root, edges |
| [3](day-planner-03-backend.md#part-3-building-the-backend-api) | [Backend API](day-planner-03-backend.md#part-3-building-the-backend-api) | `def:pub`, `jid()`, collections, list comprehensions |
| [4](day-planner-04-frontend.md#part-4-a-reactive-frontend) | [Working frontend](day-planner-04-frontend.md#part-4-a-reactive-frontend) | Client-side code, lambdas, JSX, reactive state |
| [5](day-planner-05-ai.md#part-5-making-it-smart-with-ai) | [AI features](day-planner-05-ai.md#part-5-making-it-smart-with-ai) | `by llm()`, `obj`, `sem`, structured output |
| [6](day-planner-06-auth.md#part-6-authentication-and-multi-file-organization) | [Authentication](day-planner-06-auth.md#part-6-authentication-and-multi-file-organization) | Login, signup, `def:priv`, per-user data, multi-file |
| [7](day-planner-07-walkers.md#part-7-object-spatial-programming-with-walkers) | [Walkers & OSP](day-planner-07-walkers.md#part-7-object-spatial-programming-with-walkers) | Walkers, abilities, graph traversal |

---

## Part 1: Your First Lines of Jac

[Open lesson 1: Your First Lines of Jac](day-planner-01-basics.md).

## Part 2: Modeling Data with Nodes

[Open lesson 2: Modeling Data with Nodes](day-planner-02-nodes.md).

## Part 3: Building the Backend API

[Open lesson 3: Building the Backend API](day-planner-03-backend.md).

## Part 4: A Reactive Frontend

[Open lesson 4: A Reactive Frontend](day-planner-04-frontend.md).

## Part 5: Making It Smart with AI

[Open lesson 5: Making It Smart with AI](day-planner-05-ai.md).

## Part 6: Authentication and Multi-File Organization

[Open lesson 6: Authentication and Multi-File Organization](day-planner-06-auth.md).

## Part 7: Object-Spatial Programming with Walkers

[Open lesson 7: Object-Spatial Programming with Walkers](day-planner-07-walkers.md).

## Summary

Over seven parts, you progressed from basic syntax to a complete full-stack application, then explored an alternative programming paradigm. Here's what you accomplished:

| Parts | What You Built | What It Teaches |
|-------|----------------|-----------------|
| 1–4 | Working day planner | Core syntax, graph data, reactive frontend |
| 5 | + AI features | AI delegation, structured output, semantic types |
| 6 | + Auth & multi-file | Authentication, `def:priv`, per-user isolation, declaration/implementation split |
| 7 | OSP reimplementation | Walkers, abilities, graph traversal |

The concepts you've learned are interconnected. Types constrain AI output. Graphs eliminate databases. `root` enables per-user isolation. Walkers provide an alternative to functions for graph-heavy logic. Here's a quick reference of every Jac concept covered in this tutorial:

**Data & Types:** `node`, `edge`, `obj`, `enum`, `has`, `glob`, `sem`, type annotations, `str | None` unions

**Graph:** `root`, `++>` (create + connect), `+>: Edge :+>` (typed edge), `[root-->]` (query), `[?:Type]` (filter), `jid()` (node identity), `del` (delete)

**Functions:** `def`, `def:pub`, `def:priv`, `by llm()`, `lambda`, `async`/`await`

**Walkers:** `walker`, `walker:priv`, `can with Type entry/exit`, `visit`, `here`, `self`, `visitor`, `report`, `disengage`, `spawn`

**Frontend:** inferred client placement, `JsxElement`, reactive `has`, `can with entry`, `can with [deps] entry`, JSX expressions

**Structure:** `import from` (bridging server code into the client automatically), `impl`, declaration/implementation split

**Auth:** `jacSignup`, `jacLogin`, `jacLogout`, `jacIsLoggedIn`

---

## Next Steps

Now that you have a solid foundation, here are some directions to deepen your understanding:

- **Deploy** -- [Deploy to Kubernetes](../production/kubernetes.md) with `jac scale deploy` (the built-in scale subsystem) to take your app to production
- **Go deeper on walkers** -- [Object-Spatial Programming](../language/osp.md) covers advanced graph patterns like recursive traversals and multi-hop queries
- **More AI** -- [byLLM Quickstart](../ai/quickstart.md) for standalone examples and [Agentic AI](../ai/agentic.md) for building tool-using agents
- **Examples** -- Explore [community examples](https://github.com/Jaseci-Labs/jaseci/tree/main/examples) for inspiration on what to build next
- **Language Reference** -- [Full Language Reference](../../reference/language/foundation.md) for complete syntax documentation when you need to look up specifics
