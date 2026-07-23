# Welcome to Jac

**One language, one compiler, the whole stack. No glue.**

Jac is a programming language designed for humans and AI to build together. With clean, Python-like syntax, Jac compiles to Python bytecode, JavaScript, and native machine code (C-ABI compatible), giving full access to every library in the PyPI, npm, and native ecosystems. One compiler sees the whole application: the AI calls, the data model, the API, the frontend, and the deployment are language features checked together, not frameworks assembled around a language. Jac moves complexity out of the developer's code and into the compiler and runtime.

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

This single file defines a persistent data model, an AI-powered categorizer, a REST API, and a React frontend. There is no database to set up, no hand-written prompt (the compiler derives it from your names and types), and no separate frontend project. Just Jac.

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

## The Two Ideas

Modern software fragments into a dozen notations, and defects pool at the seams no compiler can see. [Why Jac Exists](why-jac.md) counts that cost. Jac's answer is two properties, each a first in a production language:

<div class="grid cards" markdown>

- :material-vector-link:{ .lg .middle } **Synechic: one continuous medium**

    ---

    Jac presents one continuous, compiler-checked medium across tiers, ecosystems, and toolchains. The property is called *synechic*. Frontend, backend, and native code live in one language, PyPI, npm, and C libraries arrive through a plain `import`, and a `node` declared once is the same type in the store, on the wire, and in the browser. Rename a field and every stale use in every tier is a compile error.

    [:octicons-arrow-right-24: The Two Ideas](ideas-behind-jac.md#synechic) · [:octicons-arrow-right-24: How Codespaces Work](what-makes-jac-different.md#1-how-can-one-language-target-frontends-backends-and-native-binaries-at-the-same-time) · [:octicons-arrow-right-24: Full-Stack Reference](../reference/plugins/jac-client.md)

- :material-graph-outline:{ .lg .middle } **Topokinetic: computation moves to the data**

    ---

    Jac makes the moving locus of computation a language construct. The property is called *topokinetic*, and *Object-Spatial Programming* realizes it. Model your domain as typed nodes and edges, send walkers to traverse it, and mark a walker `:pub` to serve it as a REST endpoint. Whatever is reachable from `root` persists: persistence is a predicate, not an event.

    [:octicons-arrow-right-24: The Two Ideas](ideas-behind-jac.md#topokinetic) · [:octicons-arrow-right-24: OSP Reference](../reference/language/osp.md) · [:octicons-arrow-right-24: How Persistence Works](what-makes-jac-different.md#2-how-does-jac-fully-abstract-away-database-organization-and-interactions-and-the-complexity-of-multiuser-persistent-data)

</div>

The two properties compound. With one continuous medium and mobile computation together, the topology of nodes and edges is at once the data model and the store, so the database stops existing as a separate system. Jac is the first language with both properties, and [The Two Ideas](ideas-behind-jac.md) makes the full argument.

The machinery beneath them has names too:

- **[Meaning types](../reference/plugins/byllm.md)** make the model a typed executor: `by llm()` delegates a function to an LLM, and the prompt is derived from your names, types, and `sem` annotations rather than written by hand.
- **[Scale invariance](../reference/plugins/jac-scale.md#the-scale-invariance-contract)** keeps semantics fixed from `jac run` to `jac start --scale`: same program text at every deployment scale, with Kubernetes, Redis, and MongoDB provisioned by the runtime.
- **The [polypiler](one-binary.md)** compiles the whole polyglot application as one unit: its targets are ecosystems rather than instruction sets, and it ships as one self-contained binary.
- **[Gradual borrow checking](../reference/language/ownership-borrowing.md)** makes memory discipline a dial rather than a divide: managed semantics by default, ownership adopted one declaration at a time, down to native code with no collector.

---

## Build Anything

The two properties combine into whatever you're shipping: a CLI tool, a REST API, a full-stack app, a desktop or mobile build, native compute in the browser, or a redistributable library. The [**Build Anything**](project-kinds.md) hub has a small working recipe for each, and every recipe links to a guided **"I like to build…"** track that takes you from a 5-minute quick win to the full tutorials.

For the *why* and *how* beneath them (codespaces, Object-Spatial Programming, and `by llm()`), read [Core Concepts](what-makes-jac-different.md).

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

Jac is designed for developers who want to build AI-powered applications without the complexity of managing multiple languages and tools. If you've ever wished you could write your frontend, backend, AI logic, and deployment config in one place, Jac is for you.

| You Are | Jac Gives You |
|---------|---------------|
| **Startup Founder** | Ship complete products faster: one language, one deploy command |
| **AI/ML Engineer** | Native LLM integration with no hand-written prompts to maintain |
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
