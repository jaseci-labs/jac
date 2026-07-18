# Welcome to Jac

**The Only Language You Need to Build Anything**

Jac is a programming language designed for humans and AI to build together. With clean, Python-like syntax, Jac compiles to Python bytecode, JavaScript, and native machine code (C-ABI compatible) -- giving full access to every library in the PyPI, npm, and native ecosystems. Jac adds constructs that let you weave AI into your code, model complex domains as graphs, and deploy to the cloud -- all without switching languages, managing databases, or writing infrastructure. Jac imagines what should be abstracted away from the developer and automates it through the compiler and runtime.

```jac
# A complete full-stack AI app in one file

node Todo {
    has title: str, category: str = "other", done: bool = False;
}

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

def categorize(title: str) -> Category by llm();

def:pub add_todo(title: str) -> Todo {
    try {
        result = categorize(title);
        category = str(result).split(".")[-1].lower();
    } except Exception {
        category = "other (setup AI key)";
    }
    todo = Todo(title=title, category=category);
    root ++> todo;
    return todo;
}

def:pub get_todos -> list[Todo] {
    return [root-->][?:Todo];
}

cl def:pub app -> JsxElement {
    has todos: list[Todo] = [], text: str = "";
    async can with entry { todos = await get_todos(); }
    async def add {
        if text.strip() {
            todos = todos + [await add_todo(text.strip())];
            text = "";
        }
    }
    return <div>
        <input value={text}
            onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
            onKeyPress={lambda (e: KeyboardEvent) { if e.key == "Enter" { add(); } }}
            placeholder="Add a todo..." />
        <button onClick={add}>Add</button>
        {[<p key={jid(t)}>{t.title} ({t.category})</p> for t in todos]}
    </div>;
}
```

This single file defines a persistent data model, an AI-powered categorizer, a REST API, and a React frontend. No database setup. No prompt engineering. No separate frontend project. Just Jac.

??? info "You can actually run this example"
    Save the code above as `main.jac`, then create a `jac.toml` in the same directory:

    ```toml
    [project]
    name = "mini-todo"

    [dependencies.npm]
    react = "^18.2.0"
    react-dom = "^18.2.0"

    [dependencies.npm.dev]
    vite = "^6.4.1"
    "@vitejs/plugin-react" = "^4.2.1"
    typescript = "^5.3.3"
    "@types/react" = "^18.2.0"
    "@types/react-dom" = "^18.2.0"

    [serve]
    base_route_app = "app"

    [scale]

    [client]

    [byllm.model]
    default_model = "anthropic/claude-sonnet-4-6"
    ```

    Install Jac, set your API key, and run:

    ```bash
    curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
    export ANTHROPIC_API_KEY="your-key-here"
    jac start
    ```

    Open [http://localhost:8000](http://localhost:8000) to see it running. Jac supports any [LiteLLM-compatible model](https://docs.litellm.ai/docs/providers) -- use `gemini/gemini-2.5-flash` for a free alternative or `ollama/llama3.2:1b` for local models.

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

    [:octicons-arrow-right-24: How Codespaces Work](what-makes-jac-different.md#1-how-can-one-language-target-frontends-backends-and-native-binaries-at-the-same-time) · [:octicons-arrow-right-24: Full-Stack Reference](../reference/plugins/jac-client.md) · [:octicons-arrow-right-24: See Jac vs a Traditional Stack](jac-vs-traditional-stack.md)

- :material-robot:{ .lg .middle } **AI Native**

    ---

    Integrate LLMs at the language level with `by llm()` -- the compiler extracts semantics from your function names, types, and `sem` annotations to construct prompts automatically. First-class graphs and walkers give you an expressive agentic programming model where AI agents traverse structured state spaces with tool-calling built in.

    [:octicons-arrow-right-24: How by/sem Work](what-makes-jac-different.md#3-how-does-jac-abstract-away-the-laborious-task-of-promptcontext-engineering-for-ai-and-turn-it-into-a-compilerruntime-problem) · [:octicons-arrow-right-24: AI Integration Reference](../reference/plugins/byllm.md) · [:octicons-arrow-right-24: Agentic Patterns](../reference/plugins/byllm.md#agentic-ai-patterns)

- :material-cloud-outline:{ .lg .middle } **Scale Native**

    ---

    Your code doesn't change when you move from laptop to cloud. Declare `node` types and connect them to `root` -- the runtime handles persistence automatically. Run `jac start --scale` and your app deploys to Kubernetes with Redis, MongoDB, load balancing, and health checks provisioned for you. Zero DevOps.

    [:octicons-arrow-right-24: How Persistence Works](what-makes-jac-different.md#2-how-does-jac-fully-abstract-away-database-organization-and-interactions-and-the-complexity-of-multiuser-persistent-data) · [:octicons-arrow-right-24: Deployment Reference](../reference/plugins/jac-scale.md) · [:octicons-arrow-right-24: Scale Reference](../reference/plugins/jac-scale.md)

</div>

---

## Build Anything

These three pillars combine into whatever you're shipping -- a CLI tool, a REST API, a full-stack app, a desktop or mobile build, native compute in the browser, or a redistributable library. The [**Build Anything**](project-kinds.md) hub has a small working recipe for each, and every recipe links to a guided **"I like to build…"** track that takes you from a 5-minute quick win to the full tutorials.

For the *why* and *how* behind the pillars -- codespaces, object-spatial programming, and `by llm()` -- read [Core Concepts](what-makes-jac-different.md).

[:octicons-arrow-right-24: Browse what you can build](project-kinds.md)

---

## Get Started in 5 Minutes

### Step 1: Install

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

This installs the self-contained `jac` binary -- no Python, pip, or uv required. It includes the compiler, the built-in full-stack frontend/desktop framework, and the built-in `scale` subsystem for serving and deployment. Add AI integration with `jac install byllm`; scale's optional deps (MongoDB, Redis, Kubernetes, ...) are pulled per-project by your `[scale.*]` config plus `jac install`.

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

> **💡 Tip**: Add `-e all` to see type check diagnostics: `jac -e all hello.jac`. This shows errors and warnings without needing a separate `jac check`.

**That's it!** You just ran your first Jac program.

---

## Who is Jac For?

Jac is designed for developers who want to build AI-powered applications without the complexity of managing multiple languages and tools. If you've ever wished you could write your frontend, backend, AI logic, and deployment config in one place -- Jac is for you.

| You Are | Jac Gives You |
|---------|---------------|
| **Startup Founder** | Ship complete products faster -- one language, one deploy command |
| **AI/ML Engineer** | Native LLM integration without prompt engineering overhead |
| **Full-Stack Developer** | React frontend + Python backend, no context switching |
| **Python Developer** | Familiar syntax with powerful new capabilities (Jac compiles to Python bytecode -- all your libraries just work) |
| **Student/Learner** | Modern language designed for clarity, with clean syntax AI models can read and write |

!!! note "What You Should Know"
    Jac compiles to Python bytecode, so **Python familiarity is assumed** throughout these docs. If you plan to use the full-stack features, basic **React/JSX** knowledge helps. No graph database experience is needed -- Jac teaches you that.

---

## Need Help?

- **Discord**: Join our [community server](https://discord.gg/6j3QNdtcN6) for questions and discussions
- **GitHub**: Report issues at [Jaseci-Labs/jaseci](https://github.com/Jaseci-Labs/jaseci)
- **JacGPT**: Ask questions at [jac-gpt.jaseci.org](https://jac-gpt.jaseci.org)
