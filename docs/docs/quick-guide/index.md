# Welcome to Jac

**The Only Language You Need to Build Anything**

Jac is a programming language designed for humans and AI to build together. It supersets Python and JavaScript with native compilation support, adding constructs that let you weave AI into your code, model complex domains as graphs, and deploy to the cloud -- all without switching languages, managing databases, or writing infrastructure. Jac imagines what should be abstracted away from the developer and automates it through the compiler and runtime.

```jac
# A complete full-stack AI app in one file

node Todo {
    has title: str, done: bool = False;
}

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

def categorize(title: str) -> Category
    by llm();

def:pub get_todos -> list {
    return [{"title": t.title, "category": categorize(t.title)}
            for t in [root-->](?:Todo)];
}

cl def:pub app() -> JsxElement {
    has items: list = [];
    async can with entry { items = await get_todos(); }
    return <div>{[<p key={i.title}>{i.title} ({i.category})</p>
                  for i in items]}</div>;
}
```

This single file defines a persistent data model, an AI-powered categorizer, a REST API, and a React frontend. No database setup. No prompt engineering. No separate frontend project. Just Jac.

---

## The Vision

Programming today demands too much from developers that isn't their problem to solve. You want to build a product, but first you have to pick a backend language, a frontend framework, a database, an ORM, a deployment target, and then glue them all together. If you want AI, add prompt engineering to the list. If you want scale, add DevOps.

Jac takes a different approach: **move complexity out of the developer's code and into the language runtime**. The things that can be automated -- database schemas, API serialization, client-server communication, prompt construction, deployment orchestration -- should be automated. The developer should focus on *what* the application does, not *how* the plumbing works.

This philosophy rests on three pillars.

---

## Three Pillars

<div class="grid cards" markdown>

- :material-language-python:{ .lg .middle } **One Language**

    ---

    Write frontend, backend, and native code in a single language. Jac's **codespace** system lets you target the server (`sv`), browser (`cl`), or native binary (`na`) from the same file. The compiler handles interop -- HTTP calls, serialization, type sharing -- so you never write glue code.

    [:octicons-arrow-right-24: How Codespaces Work](what-makes-jac-different.md#1-how-can-one-language-target-frontends-backends-and-native-binaries-at-the-same-time) · [:octicons-arrow-right-24: Full-Stack Reference](../reference/language/full-stack.md) · [:octicons-arrow-right-24: See Jac vs a Traditional Stack](jac-vs-traditional-stack.md)

- :material-robot:{ .lg .middle } **AI Native**

    ---

    Integrate LLMs at the language level with `by llm()` -- the compiler extracts semantics from your function names, types, and `sem` annotations to construct prompts automatically. First-class graphs and walkers give you an expressive agentic programming model where AI agents traverse structured state spaces with tool-calling built in.

    [:octicons-arrow-right-24: How by/sem Work](what-makes-jac-different.md#3-how-does-jac-abstract-away-the-laborious-task-of-promptcontext-engineering-for-ai-and-turn-it-into-a-compilerruntime-problem) · [:octicons-arrow-right-24: AI Integration Reference](../reference/language/ai-integration.md) · [:octicons-arrow-right-24: Agentic Patterns](../reference/language/ai-integration.md#agentic-ai-patterns)

- :material-cloud-outline:{ .lg .middle } **Scale Native**

    ---

    Your code doesn't change when you move from laptop to cloud. Declare `node` types and connect them to `root` -- the runtime handles persistence automatically. Run `jac start --scale` and your app deploys to Kubernetes with Redis, MongoDB, load balancing, and health checks provisioned for you. Zero DevOps.

    [:octicons-arrow-right-24: How Persistence Works](what-makes-jac-different.md#2-how-does-jac-fully-abstract-away-database-organization-and-interactions-and-the-complexity-of-multiuser-persistent-data) · [:octicons-arrow-right-24: Deployment Reference](../reference/language/deployment.md) · [:octicons-arrow-right-24: jac-scale Plugin](../reference/plugins/jac-scale.md)

</div>

---

## One Language: Frontend, Backend, Native

Jac introduces **codespaces** -- regions of code that target different execution environments. Instead of maintaining separate projects in separate languages, you write everything in Jac and the compiler produces the right output for each target:

| Codespace | Target | Ecosystem | Syntax |
|-----------|--------|-----------|--------|
| **Server** | Python runtime | PyPI (`numpy`, `pandas`, `fastapi`) | `sv { }` or `.sv.jac` |
| **Client** | Browser/JavaScript | npm (`react`, `tailwind`, `@mui`) | `cl { }` or `.cl.jac` |
| **Native** | Compiled binary | C ABI | `na { }` or `.na.jac` |

Server definitions are visible to client blocks. When the client calls a server function, the compiler generates the HTTP request, serialization, and routing automatically. You write one language; the compiler produces the interop layer.

!!! example "See it in action"
    Want to see exactly how much code Jac eliminates? Check out [Jac vs Traditional Stack](jac-vs-traditional-stack.md) -- a side-by-side comparison showing **~30 lines of Jac** vs **>300 lines** of Python + FastAPI + SQLite + TypeScript + React for the same Todo app.

---

## AI Native: LLMs as Code Constructs

Jac's approach to AI is called [Meaning Typed Programming](https://arxiv.org/pdf/2405.08965). Instead of writing prompts in strings and parsing responses manually, you declare **what** you want through function signatures and let the compiler handle the **how**:

```jac
# The function name, types, and return type ARE the specification
def classify_sentiment(text: str) -> str by llm;

# Enums constrain the LLM to valid outputs
enum Priority { LOW, MEDIUM, HIGH, CRITICAL }
def triage_ticket(description: str) -> Priority by llm();

# sem provides additional semantic context where names aren't enough
obj Ingredient {
    has name: str, cost: float, carby: bool;
}
sem Ingredient.cost = "Estimated cost in USD";
sem Ingredient.carby = "True if high in carbohydrates";

def plan_shopping(recipe: str) -> list[Ingredient] by llm();
```

The return type serves as the output contract -- `enum` means the LLM can only produce one of its values, `obj` means every field must be filled. No parsing code. No validation code. The type system enforces correctness.

For **agentic workflows**, Jac's graph constructs (nodes, edges, walkers) naturally model AI agents that traverse structured state spaces, make decisions with `by llm()`, and call tools:

```jac
def get_weather(city: str) -> str { return fetch_weather_api(city); }
def search_web(query: str) -> list[str] { return web_search_api(query); }

# The LLM decides which tools to call and in what order
def answer_question(question: str) -> str
    by llm(tools=[get_weather, search_web]);
```

[:octicons-arrow-right-24: byLLM Quickstart Tutorial](../tutorials/ai/quickstart.md) · [:octicons-arrow-right-24: Agentic AI Tutorial](../tutorials/ai/agentic.md)

---

## Scale Native: No Code Changes from Laptop to Cloud

Every Jac program has a built-in `root` node. Nodes reachable from `root` are **persistent** -- they survive process restarts. The runtime generates storage schemas from your node declarations. You never write database code:

```jac
node Todo { has title: str, done: bool = False; }

with entry {
    root ++> Todo(title="Learn Jac");  # Automatically persisted
}
```

This same program runs three ways with no code changes:

| Command | What Happens |
|---------|-------------|
| `jac app.jac` | Runs locally, SQLite persistence |
| `jac start app.jac` | HTTP API server, walkers become REST endpoints |
| `jac start --scale` | Kubernetes deployment with Redis, MongoDB, load balancing |

The runtime handles database schemas, user authentication (per-user graph isolation), API generation (Swagger docs at `/docs`), caching tiers, and Kubernetes orchestration. You write application logic; the runtime handles infrastructure.

[:octicons-arrow-right-24: Production Deployment Tutorial](../tutorials/production/local.md) · [:octicons-arrow-right-24: Kubernetes Tutorial](../tutorials/production/kubernetes.md)

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

Note: `jac` is shorthand for `jac run` -- both work identically.

**That's it!** You just ran your first Jac program.

---

## Choose Your Path

<div class="grid cards" markdown>

- :material-rocket-launch:{ .lg .middle } **Just want to try it?**

    ---

    Follow the [Installation](install.md) guide to get set up and run your first program in 2 minutes.

- :material-web:{ .lg .middle } **Building a web app?**

    ---

    Jump to [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md) -- a complete 7-part tutorial covering backend, frontend, persistence, auth, and AI.

- :material-robot:{ .lg .middle } **Working with AI/LLMs?**

    ---

    Start with the [byLLM Quickstart](../tutorials/ai/quickstart.md), then explore [Agentic AI](../tutorials/ai/agentic.md) for tool-calling agents and multi-agent systems.

- :material-graph:{ .lg .middle } **Interested in graphs and OSP?**

    ---

    Read [What Makes Jac Different](what-makes-jac-different.md) for the concepts, then the [OSP Tutorial](../tutorials/language/osp.md) for hands-on practice with nodes, edges, and walkers.

</div>

---

## Who is Jac For?

Jac is designed for developers who want to build AI-powered applications without the complexity of managing multiple languages and tools. If you've ever wished you could write your frontend, backend, AI logic, and deployment config in one place -- Jac is for you.

| You Are | Jac Gives You |
|---------|---------------|
| **Startup Founder** | Ship complete products faster -- one language, one deploy command |
| **AI/ML Engineer** | Native LLM integration without prompt engineering overhead |
| **Full-Stack Developer** | React frontend + Python backend, no context switching |
| **Python Developer** | Familiar syntax with powerful new capabilities (Jac supersets Python) |
| **Student/Learner** | Modern language designed for clarity, with clean syntax AI models can read and write |

!!! note "What You Should Know"
    Jac supersets Python, so **Python familiarity is assumed** throughout these docs. If you plan to use the full-stack features, basic **React/JSX** knowledge helps. No graph database experience is needed -- Jac teaches you that.

---

## Quick Links

| Resource | Description |
|----------|-------------|
| [Installation](install.md) | Setup, first program, scaffolding, and Jacpacks |
| [What Makes Jac Different](what-makes-jac-different.md) | The three core concepts: codespaces, OSP, and AI integration |
| [Syntax Cheatsheet](syntax-cheatsheet.md) | Comprehensive syntax reference |
| [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md) | Complete 7-part tutorial covering all Jac features |
| [Language Reference](../reference/language/foundation.md) | Complete language documentation |
| [CLI Reference](../reference/cli/index.md) | All `jac` commands |
| [FAQ](faq.md) | Learning paths by experience level |

---

## Need Help?

- **Discord**: Join our [community server](https://discord.gg/6j3QNdtcN6) for questions and discussions
- **GitHub**: Report issues at [Jaseci-Labs/jaseci](https://github.com/Jaseci-Labs/jaseci)
- **JacGPT**: Ask questions at [jac-gpt.jaseci.org](https://jac-gpt.jaseci.org)
