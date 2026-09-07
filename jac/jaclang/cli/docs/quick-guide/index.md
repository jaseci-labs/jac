# Welcome to Jac

Jac is a programming language for server, browser, and native code. It combines familiar imperative programming with graph traversal and functions implemented by language models. Its compiler uses shared declarations to generate supported cross-tier calls and check their types.

Choose a starting point:

- [Install Jac](install.md) and run your first program.
- [Jac Fundamentals](../tutorials/language/basics.md) introduces the syntax for readers who already program.
- [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md) teaches Jac through seven lessons.
- [Project Kinds](project-kinds.md) helps you select a target for an existing idea.

The example below previews a web application. Its configuration and model setup follow the code; the day-planner lessons explain the constructs one at a time.

```jac
# Application source; configuration follows below

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

def:pub app -> JsxElement {
    has todos: list[Todo] = [], text: str = "";
    async can with entry { todos = await get_todos(); }
    async def add {
        if text.strip() {
            todos = todos + [await add_todo(text.strip())];
            text = "";
        }
    }
    <div>
        <input value={text}
            onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
            onKeyPress={lambda (e: KeyboardEvent) { if e.key == "Enter" { add(); } }}
            placeholder="Add a todo..." />
        <button onClick={add}>Add</button>
        {[<p key={jid(t)}>{t.title} ({t.category})</p> for t in todos]}
    </div>
}
```

This file declares the data model, categorization function, server endpoints, and client interface. Jac generates the supported connections between them. Running it also requires the project configuration, dependencies, and model access described below.

??? info "You can actually run this example"
    Save the code above as `main.jac`, then create a `jac.toml` in the same directory:

    ```toml
    [project]
    name = "mini-todo"

    [dependencies.npm]
    react = "^19.2.0"
    react-dom = "^19.2.0"

    [dependencies.npm.dev]
    vite = "^6.4.1"
    "@vitejs/plugin-react" = "^4.2.1"
    typescript = "^5.3.3"
    "@types/react" = "^19.2.0"
    "@types/react-dom" = "^19.2.0"

    [scale]

    [client]

    [byllm.model]
    default_model = "anthropic/claude-sonnet-4-6"
    ```

    Install Jac, set your API key, and run:

    ```bash
    curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
    export ANTHROPIC_API_KEY="your-key-here"
    jac run
    ```

    Open [http://localhost:8000](http://localhost:8000) to see it running. Jac supports any [LiteLLM-compatible model](https://docs.litellm.ai/docs/providers) -- use `gemini/gemini-2.5-flash` for a free alternative or `ollama/llama3.2:1b` for local models.

---

## The Two Ideas

Two independent ideas guide Jac's design: continuity across execution environments and computation expressed through graph traversal. These are useful background; the tutorials introduce their concrete syntax and behavior.

<div class="grid cards" markdown>

- :material-vector-link:{ .lg .middle } **Synechic: one continuous medium**

    ---

    The synechic class concerns continuity across runtimes, ecosystems, and toolchains. Jac applies this idea through shared declarations, placement inference, and compiler-generated bridges for supported cross-tier operations.

    [:octicons-arrow-right-24: The Two Ideas](ideas-behind-jac.md#synechic) · [:octicons-arrow-right-24: How Codespaces Work](what-makes-jac-different.md#1-how-can-one-language-target-frontends-backends-and-native-binaries-at-the-same-time) · [:octicons-arrow-right-24: Full-Stack Reference](../reference/plugins/jac-client.md)

- :material-graph-outline:{ .lg .middle } **Topokinetic: computation moves to the data**

    ---

    The topokinetic class makes traversal a way to express computation. In Jac, nodes and edges model relationships and walkers carry state through them. Graphs can be transient or persisted through the runtime.

    [:octicons-arrow-right-24: The Two Ideas](ideas-behind-jac.md#topokinetic) · [:octicons-arrow-right-24: OSP Reference](../reference/language/osp.md) · [:octicons-arrow-right-24: How Persistence Works](what-makes-jac-different.md#2-how-does-jac-fully-abstract-away-database-organization-and-interactions-and-the-complexity-of-multiuser-persistent-data)

</div>

The properties are independent and can be combined. A server walker can traverse related records and report a result to a client through a generated bridge. [The Two Ideas](ideas-behind-jac.md) explains the design and its limits.

The machinery beneath them has names too:

- **[Meaning types](../reference/plugins/byllm.md)** make the model a typed executor: `by llm()` delegates a function to an LLM, and the prompt is derived from your names, types, and `sem` annotations rather than written by hand.
- **[Scale invariance](../reference/plugins/jac-scale.md#the-scale-invariance-contract)** describes the runtime contract for preserving supported application behavior across deployment configurations. Resource limits, failures, and operational setup remain relevant.
- **The [polypiler](one-binary.md)** compiles the whole polyglot application as one unit: its targets are ecosystems rather than instruction sets, and it ships as one self-contained binary.
- **[Gradual borrow checking](../reference/language/ownership-borrowing.md)** makes memory discipline a dial rather than a divide: managed semantics by default, ownership adopted one declaration at a time, down to native code with no collector.

---

## Build Anything

The [project kinds](project-kinds.md) page links to recipes for CLI tools, APIs, web applications, desktop and mobile builds, and reusable libraries. Choose a track based on the artifact you need.

For the *why* and *how* beneath them (codespaces, Object-Spatial Programming, and `by llm()`), read [Core Concepts](what-makes-jac-different.md).

[:octicons-arrow-right-24: Browse what you can build](project-kinds.md)

---

## Run Your First Program {#get-started-in-5-minutes}

### Step 1: Install

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

This installs the self-contained `jac` binary -- no Python, pip, or uv required. It includes the compiler, the built-in full-stack frontend/desktop framework, and the built-in `scale` subsystem for serving and deployment. byLLM integration is included; scale's optional deps (Kubernetes, Prometheus, OpenTelemetry, ...) are pulled per-project by your `[scale.*]` config plus `jac install`.

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

The output should be `Hello from Jac!`. Change the string and run the file again to verify the edit.

---

## Who is Jac For?

These docs assume basic programming knowledge. If you are new to programming, begin with the [coding primer](../tutorials/language/coding_primer.md). Python experience helps with expressions and control flow; HTML and JSX experience helps with browser components. The graph tutorials introduce nodes, edges, and walkers without assuming graph-database experience.

---

## Need Help?

- **Discord**: Join our [community server](https://discord.gg/6j3QNdtcN6) for questions and discussions
- **GitHub**: Report issues at [Jaseci-Labs/jaseci](https://github.com/Jaseci-Labs/jaseci)
- **JacGPT**: Ask questions at [jac-gpt.jaseci.org](https://jac-gpt.jaseci.org)
