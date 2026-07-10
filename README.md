<div align="center">
  <img alt="Jac logo" src="docs/docs/assets/logo.png" width="80px">

  <h1>The Jac Programming Language</h1>
  <h3>The Only Language You Need to Build Anything</h3>

  <p>One self-contained binary. One Python-like language. AI, graphs, persistence, APIs, UIs, and cloud deployment as language features, compiled to Python bytecode, JavaScript, and native machine code.</p>

  <p>
    <a href="https://github.com/jaseci-labs/jaseci/releases/latest">
      <img src="https://img.shields.io/github/v/release/jaseci-labs/jaseci?style=flat-square" alt="Latest release">
    </a>
    <a href="https://github.com/jaseci-labs/jaseci/actions/workflows/ci.yml">
      <img src="https://img.shields.io/github/actions/workflow/status/jaseci-labs/jaseci/ci.yml?branch=main&style=flat-square&label=CI" alt="CI status">
    </a>
    <a href="https://codecov.io/gh/Jaseci-Labs/jaseci">
      <img src="https://img.shields.io/codecov/c/github/Jaseci-Labs/jaseci?style=flat-square" alt="Code coverage">
    </a>
    <a href="https://github.com/jaseci-labs/jaseci/stargazers">
      <img src="https://img.shields.io/github/stars/jaseci-labs/jaseci?style=flat-square&logo=github&label=stars&color=f7b731" alt="GitHub stars">
    </a>
    <a href="https://github.com/jaseci-labs/jaseci/releases">
      <img src="https://img.shields.io/github/downloads/jaseci-labs/jaseci/total?style=flat-square&label=downloads" alt="Release downloads">
    </a>
    <a href="https://discord.gg/6j3QNdtcN6">
      <img src="https://img.shields.io/discord/1105093583750574120?style=flat-square&logo=discord&logoColor=white&label=discord&color=5865F2" alt="Discord members online">
    </a>
    <a href="LICENSE">
      <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT license">
    </a>
  </p>

  <p>
    <a href="https://docs.jaseci.org"><b>Docs</b></a> ·
    <a href="https://playground.jaseci.org"><b>Playground</b></a> ·
    <a href="https://docs.jaseci.org/tutorials/first-app/build-ai-day-planner/"><b>Tutorial</b></a> ·
    <a href="https://discord.gg/6j3QNdtcN6"><b>Discord</b></a>
  </p>

  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/docs/assets/readme/demo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="docs/docs/assets/readme/demo-light.svg">
    <img alt="Install jac, create a web app, and serve it in three commands" src="docs/docs/assets/readme/demo-light.svg" width="880">
  </picture>
</div>

Jac is a programming language designed for humans and AI to build together. It compiles one clean, Python-like syntax to Python bytecode, JavaScript, and native machine code, with the entire PyPI, npm, and C ecosystems available without wrappers or interop layers. The things every real application needs (an LLM call, a data model that persists, a REST API, a frontend, a deployment story) are language features, not frameworks you assemble around it.

## Try Jac in 30 seconds

Install the self-contained `jac` binary. No Python, pip, Node, or C toolchain required:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

Save this as `hello.jac`:

```jac
node Person {
    has name: str;
}

walker Greeter {
    can start with Root entry {
        visit [-->];
    }
    can greet with Person entry {
        print(f"Hello, {here.name}!");
        visit [-->];
    }
}

with entry {
    root ++> Person(name="Ada");
    root ++> Person(name="Alan");
    root spawn Greeter();
}
```

```bash
jac run hello.jac
```

```text
Hello, Ada!
Hello, Alan!
```

Now run it again: the people accumulate. The graph hanging off `root` **persists between runs automatically**, and that same machinery backs Jac servers in production. No database to set up, ever.

> Don't want to install anything? Open the [**Jac Playground**](https://playground.jaseci.org) in your browser.
>
> Prebuilt binaries ship for **macOS and Linux**; on Windows, use WSL (a native PowerShell installer is coming soon). See the [installation guide](https://docs.jaseci.org/quick-guide/install/) for versions, upgrading, and IDE setup.

## For AI agents

Jac is designed for humans and AI to build together, and that includes your coding agent. The `jac` binary ships an MCP server with Jac validation, formatting, docs, and examples built in. Wire it into Claude Code with one command:

```bash
claude mcp add jac -- jac mcp
```

For Cursor, Windsurf, or any other MCP client, add this to your MCP config (use `jac mcp --mode lite` for smaller models):

```json
{ "mcpServers": { "jac": { "command": "jac", "args": ["mcp"] } } }
```

Or skip the setup entirely and paste this into your agent's chat; it will install Jac and configure itself:

```text
Fetch https://raw.githubusercontent.com/jaseci-labs/jaseci/main/SKILL.md and follow its instructions.
```

LLM-friendly docs pointers live at [docs.jaseci.org/llms.txt](https://docs.jaseci.org/llms.txt), and `jac ai` gives you a Jac-fluent coding agent in your terminal with no setup at all.

## One binary, your whole toolchain

One download replaces the interpreter, the JS runtime, the compilers and linker, the package managers, the server, and the deployer:

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/docs/assets/readme/one-binary-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="docs/docs/assets/readme/one-binary-light.svg">
    <img alt="The jac binary bundles CPython, Bun, LLVM and a Zig linker, a package manager, a REST server, and a Kubernetes deployer, and builds every kind of artifact" src="docs/docs/assets/readme/one-binary-light.svg" width="880">
  </picture>
</div>

<details>
<summary><strong>What's inside the binary (and what you can uninstall)</strong></summary>

<br>

| Capability | What it replaces | How you use it |
|---|---|---|
| **CPython 3.14** | System Python, pyenv, venvs | Bundled -- runs your `.jac` files and PyPI imports |
| **Bun** | Node.js, npm, npx | Bundled -- compiles `cl` code to JS, manages npm deps |
| **LLVM + Zig linker** | gcc, clang, make, cmake | Bundled -- `jac build --as native` produces real binaries |
| **Package manager** | pip, npm, pipx | `jac install` for PyPI *and* npm, in one `jac.toml` |
| **Universal tool runner** | npx, pipx run | `jac x` runs any installed PyPI or npm CLI tool |
| **REST server** | Flask, FastAPI, Express | `jac start` -- walkers become API endpoints |
| **Kubernetes deployer** | Docker + kubectl + Helm | `jac start --scale` -- one-command K8s deployment |
| **AI integration** | LangChain, prompt libraries | `by llm()` -- built into the language |
| **MCP server** | Separate MCP packages | `jac mcp` -- AI-assisted development, built in |
| **Type checker** | mypy, pyright, tsc | `jac check` |
| **Formatter & test runner** | black, ruff, pytest, jest | `jac fmt`, `jac test` |
| **Language server** | Separate LSP packages | `jac lsp` -- IDE support built in |

Full story: [One Binary, Build Anything](https://docs.jaseci.org/quick-guide/one-binary/).

</details>

The commands you'll use every day:

| Command | What it does |
| :--- | :--- |
| `jac run main.jac` | Run a program (like `python3`, but for anything) |
| `jac dev` | Live dev loop with hot reload |
| `jac start` | Serve your program: REST API, auth, Swagger docs, frontend |
| `jac build` | Type-check the whole project and emit a sealed app bundle |
| `jac build --as native` | Compile to a standalone, zero-dependency executable |
| `jac install` / `jac x` | Manage PyPI + npm deps / run any installed CLI tool |
| `jac check` / `jac fmt` / `jac test` | Type-check, format, test |
| `jac ai` / `jac mcp` / `jac guide` | Built-in coding agent, MCP server, curated docs |

## Build anything

One language and one skill set produce every kind of software. Each row is one command away:

| What you're building | The command | Guide |
|---|---|---|
| Script / CLI tool | `jac run app.jac` | [CLI & native](https://docs.jaseci.org/build/cli-and-native/) |
| Zero-dependency native executable | `jac build --as native` | [CLI & native](https://docs.jaseci.org/build/cli-and-native/) |
| Single-file app bundle (`.jab`) | `jac build` | [CLI reference](https://docs.jaseci.org/reference/cli/#jac-build) |
| Self-contained app executable | `jac build --as binary` | [CLI reference](https://docs.jaseci.org/reference/cli/#jac-build) |
| REST API (+ Swagger, auth, persistence) | `jac start api.jac` | [Backend APIs](https://docs.jaseci.org/build/backend-apis/) |
| Microservices | `sv import` + `jac start` | [Backend APIs](https://docs.jaseci.org/build/backend-apis/) |
| Full-stack web app | `jac start` | [Full-stack web](https://docs.jaseci.org/build/fullstack-web/) |
| Desktop app (native webview) | `jac build --client desktop` | [Desktop & mobile](https://docs.jaseci.org/build/desktop-mobile/) |
| Mobile app (Android / iOS) | `jac build --client mobile` | [Desktop & mobile](https://docs.jaseci.org/build/desktop-mobile/) |
| AI agents & LLM apps | `by llm()` | [AI agents](https://docs.jaseci.org/build/ai-agents/) |
| Python package (PyPI wheel) | `jac build --as wheel` | [Libraries](https://docs.jaseci.org/build/libraries/) |
| npm package | `jac build --as npm` | [Libraries](https://docs.jaseci.org/build/libraries/) |
| C-ABI shared library (`.so`/`.dylib`/`.dll`) | `jac nacompile lib.na.jac --shared` | [Libraries](https://docs.jaseci.org/build/libraries/) |
| WebAssembly in the browser | `jac build` in a `web-static` project | [Native pathway](https://docs.jaseci.org/reference/language/native-pathway/) |
| Kubernetes deployment | `jac start --scale` | [Deploy & scale](https://docs.jaseci.org/reference/plugins/jac-scale/) |

Proof it's real: a [playable chess engine](https://docs.jaseci.org/tutorials/native/chess/) compiled to a standalone binary, a [raylib game running as WebAssembly](jac/examples/raylib_shooter/web) in the browser, and [littleX](jac/examples/littleX), a full Twitter-style social app, backend to frontend, in about 1,100 lines of Jac.

## AI, graphs, and UIs are language features

### Call an LLM like a function

```jac
enum Priority { LOW, MEDIUM, HIGH, URGENT }

def assess(ticket: str) -> Priority by llm();

with entry {
    print(assess("Checkout is down and customers are leaving!"));
    # Priority.URGENT
}
```

No prompt, no parsing, no API glue. The compiler constructs the prompt from your function's name, argument names, and types (plus optional `sem` annotations), and the return type is an enforced output schema. This is [Meaning-Typed Programming](https://arxiv.org/abs/2405.08965). Declare your model once in `jac.toml`, run `jac install byllm`, and use any [LiteLLM-compatible provider](https://docs.litellm.ai/docs/providers), or go fully local with `jac install 'byllm[local]'`. [Learn more →](https://docs.jaseci.org/reference/plugins/byllm/)

### Your data is a graph, and your API writes itself

```jac
node Task {
    has title: str;
    has done: bool = False;
}

walker:pub add_task {
    has title: str;
    can create with Root entry {
        task = Task(title=self.title);
        root ++> task;
        report {"id": jid(task), "title": task.title};
    }
}

walker:pub list_tasks {
    can fetch with Root entry {
        report [{"id": jid(t), "title": t.title, "done": t.done}
                for t in [-->][?:Task]];
    }
}
```

```bash
jac start api.jac --no-client   # POST /walker/add_task · /walker/list_tasks
```

Model your domain as nodes and edges; send **walkers** to traverse it. Mark a walker `:pub` and `jac start` turns it into a REST endpoint: request bodies map onto its fields, `report` becomes the JSON response, Swagger docs appear at `/docs`, and every user gets their own isolated, persistent graph. No ORM, no schema migrations, no session plumbing. [Graphs & walkers →](https://docs.jaseci.org/tutorials/language/osp/)

### Frontend and backend in one file

```jac
node Todo {
    has title: str, done: bool = False;
}

def:pub add_todo(title: str) -> Todo {
    todo = Todo(title=title);
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
            onChange={lambda e: ChangeEvent { text = e.target.value; }}
            placeholder="Add a todo..." />
        <button onClick={add}>Add</button>
        {[<p key={jid(t)}>{t.title}</p> for t in todos]}
    </div>;
}
```

Code in `cl` compiles to a React/JSX bundle for the browser; everything else compiles to Python for the server. That `await add_todo(...)` in the click handler is a real RPC: the compiler generates the HTTP call, serialization, and shared types across the boundary. `jac start` serves it; `jac start --dev` gives you hot reload. [Full-stack tutorial →](https://docs.jaseci.org/build/fullstack-web/)

For all three ideas in one file (an AI categorizer, a native-compiled scoring function, a persistent graph, and a React UI), see [`jac/examples/mini_todo`](jac/examples/mini_todo).

## Laptop to Kubernetes without changing your code

```bash
jac start main.jac           # local: REST API + auth + Swagger + persistence
jac start main.jac --scale   # cloud: Kubernetes with Redis, MongoDB, load balancing
```

Your code doesn't change when you outgrow one machine. The `scale` subsystem ships inside the binary: `--scale` builds the images, provisions Redis and MongoDB, and deploys to Kubernetes with health checks. Zero Dockerfiles, zero YAML, zero DevOps. [Deploy & scale →](https://docs.jaseci.org/reference/plugins/jac-scale/)

## Learn Jac

- [**Build an AI Day Planner**](https://docs.jaseci.org/tutorials/first-app/build-ai-day-planner/) -- the flagship tutorial: every core concept in one guided full-stack project
- [**Jac Fundamentals**](https://docs.jaseci.org/tutorials/language/basics/) -- the language itself, for Python developers
- [**Build a Chess Engine**](https://docs.jaseci.org/tutorials/native/chess/) -- the native pathway, from source to standalone binary
- [**WebAssembly in the Browser**](https://docs.jaseci.org/tutorials/native/wasm/) -- native-speed compute, client-side
- [**Jac Playground**](https://playground.jaseci.org) -- run Jac in your browser, and [**Ask Jac GPT**](https://jac-gpt.jaseci.org) -- a docs-trained assistant
- In your terminal: `jac guide` (curated references), `jac ai` (interactive coding agent), `jac mcp` (wire Jac expertise into Claude Code, Cursor, and friends)

## What's in this repo

This is the Jaseci monorepo, home to everything that makes Jac work:

| Directory | What it is |
|---|---|
| [`jac/`](jac/) | **jaclang** -- the compiler, runtime, and everything inside the `jac` binary: the language, the full-stack client framework, the `scale` deployment subsystem, the MCP server, and the LLVM native pathway |
| [`jac-byllm/`](jac-byllm/) | **byllm** -- AI/LLM integration via Meaning-Typed Programming (`jac install byllm`) |
| [`docs/`](docs/) | The documentation site at [docs.jaseci.org](https://docs.jaseci.org) |
| [`scripts/`](scripts/) | The installer and release tooling |

The official VS Code extension lives at [jaseci-labs/jac-vscode](https://github.com/jaseci-labs/jac-vscode).

## Research

Jac's core ideas are peer-reviewed research, not just design taste. The project grew out of research at the University of Michigan and is now developed in the open by a global community. Citing Jac in your own work? GitHub's "Cite this repository" button (powered by [CITATION.cff](CITATION.cff)) gives a ready-made reference.

## Built with Jac

| Project | Description |
|---------|-------------|
| [**Tobu**](https://tobu.life/) | AI-powered memory keeper for the stories behind your photos and videos |
| [**TrueSelph**](https://trueselph.com/) | Production-grade scalable agentic conversational AI platform |
| [**Myca**](https://www.myca.ai/) | AI-powered productivity tool for high-performing individuals |
| [**Pocketnest Birdy AI**](https://www.pocketnest.com/) | Commercial financial AI powered by your own financial journey |

Building something with Jac? Tell us on [Discord](https://discord.gg/6j3QNdtcN6) and we'll add it here.

Jaseci is a member of the [NVIDIA Inception Program](https://www.nvidia.com/en-us/startups/) for cutting-edge AI startups.

## Contributing

We welcome contributions of every size, from typo fixes to compiler passes.

- **Ask questions & share ideas** on our [Discord server](https://discord.gg/6j3QNdtcN6)
- **Report bugs** via [GitHub issues](https://github.com/jaseci-labs/jaseci/issues)
- **Send PRs**: start with the [contributing guide](https://docs.jaseci.org/community/contributing/) and [CONTRIBUTING.md](CONTRIBUTING.md); `bash scripts/fresh_env.sh` sets up a dev environment

If Jac looks useful to you, [**star the repo**](https://github.com/jaseci-labs/jaseci/stargazers). It helps other developers discover the project.

## License

Jac and the Jaseci stack are [MIT licensed](LICENSE). Vendored third-party components retain their own permissive licenses.

<div align="center">
  <a href="https://star-history.com/#jaseci-labs/jaseci&Date">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=jaseci-labs/jaseci&type=Date&theme=dark">
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=jaseci-labs/jaseci&type=Date">
      <img alt="Star history of jaseci-labs/jaseci" src="https://api.star-history.com/svg?repos=jaseci-labs/jaseci&type=Date" width="600">
    </picture>
  </a>
</div>
