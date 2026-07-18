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

Then clone and run [**this_is_jac**](https://github.com/jaseci-labs/this_is_jac), a showcase site built entirely in Jac:

```bash
git clone https://github.com/jaseci-labs/this_is_jac
cd this_is_jac
jac install   # first run: pulls python + npm deps
jac start     # builds the frontend + wasm, serves on http://localhost:8000
```

Open <http://localhost:8000> and scroll. Sign the guestbook -- it's backed by walkers writing to a real graph that **persists automatically, no database to set up**. Spawn a walker that traverses that graph live, play a native-compiled shooter running in the browser as WebAssembly, and poke at a full social app embedded as a single component. One language, one codebase, all the way down.

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
    <img alt="The jac binary links in CPython, Bun, LLVM and a Zig linker, a package manager, a REST server, and a Kubernetes deployer, and builds every kind of artifact" src="docs/docs/assets/readme/one-binary-light.svg" width="880">
  </picture>
</div>

<details open>
<summary><strong>What's inside the binary (and what you can uninstall)</strong></summary>

<br>

Here is the actual anatomy. The `jac` you download is a small native **launcher stub** with the entire **runtime payload** appended to the same file. The first run unpacks the payload into a per-version cache; every run after that is instant.

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/docs/assets/readme/binary-anatomy-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="docs/docs/assets/readme/binary-anatomy-light.svg">
    <img alt="Anatomy of the jac binary: a native launcher stub plus a runtime payload carrying a private CPython, the precompiled Jac compiler and runtime, a statically linked LLVM, the Bun executable, vendored typeshed stubs, and static libc archives" src="docs/docs/assets/readme/binary-anatomy-light.svg" width="880">
  </picture>
</div>

| Component | How it's in the binary | What you can uninstall |
|---|---|---|
| **Launcher stub** | The `jac` file itself: native machine code linked against libc only; everything below rides in the appended payload | -- |
| **CPython 3.14** | A private [python-build-standalone](https://github.com/astral-sh/python-build-standalone) build (PGO+LTO, stripped), `dlopen`ed by the launcher at startup -- your system Python is never consulted | Python, pyenv, conda |
| **Jac compiler + runtime** | Precompiled to JIR in the payload's private site -- includes the REST server (`jac start`), client framework, K8s deployer (`--scale`), and byLLM (`by llm()`); their optional third-party deps (litellm, pymongo, ...) resolve per-project via `jac install` | Flask, FastAPI, Express · Docker, kubectl, Helm · LangChain |
| **Bun** | The real Bun executable, carried inside the payload and invoked by absolute path -- never on your `PATH` | Node.js, npm, npx, yarn |
| **LLVM 22** | Statically linked into a single `jacllvm` shared library behind the llvmlite ABI | gcc, clang |
| **Linker + C floor** | Jac's own linker emits ELF / Mach-O / PE / wasm directly; static libc + crt archives, a musl runtime (Linux), and wasm32 libc bitcode are vendored in the payload | ld, lld, make, cmake, emscripten |
| **Package manager** | pip runs inside the private interpreter, npm resolution goes through the carried Bun -- one `jac.toml`, an automatic `.jac/venv`, and `jac x` to run any installed CLI tool | pip, pipx, uv, poetry, venv/virtualenv |
| **Type checker** | Built into the compiler (`jac check`), with the typeshed stdlib stubs vendored at a pinned commit | mypy, pyright, tsc |
| **Dev tooling** | Formatter, test runner, language server, and MCP server are modules of the same site (`jac fmt` / `jac test` / `jac lsp` / `jac mcp`) | black, ruff, pytest, jest |
| **`jac ninja` editor** | A pinned Neovim fork statically linked into the launcher itself -- boots in milliseconds, with `jac lsp` pre-wired | a separate editor + LSP setup |

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

## And build it better

Each of those deliverables is a **project kind**: `jac create myapp --kind <kind>` scaffolds it, stamps the kind into `jac.toml`, and a bare `jac run` already knows whether to execute, serve, or build it. The scaffolding is the small part -- the point is what the language does for each kind that a traditional stack makes you assemble by hand:

| `--kind` | What you ship | What Jac adds beyond a traditional language |
|---|---|---|
| `cli` | Terminal script / tool | Graph-native data modeling in a one-off script, a `root` graph that **persists between runs** (no database, no files), and `by llm()` AI with zero glue -- where a script normally means Python + SQLite + an LLM SDK |
| `cli-native` | Compiled program, run in place | The same source compiled through **statically linked LLVM** -- C-level speed with no gcc, clang, or rustc installed |
| `native-binary` | Zero-dependency executable | Jac's own linker emits the ELF/Mach-O/PE file (no `ld` in the loop) -- ship to machines with no Jac and no Python, territory that normally means learning C, Rust, or Go |
| `native-lib` | C-ABI shared library (`.so`/`.dylib`/`.dll`) | Expose Jac to **any language with a C FFI** (C, Rust, Go, Python `ctypes`) by marking functions `:pub` -- refcounted handles included, and `--target` **cross-builds for Linux/macOS/Windows** with no extra toolchain |
| `service` | Headless REST API | `walker:pub` **is** the endpoint: request bodies map to its fields, `report` is the JSON response, Swagger at `/docs`, and per-user isolated persistence -- no FastAPI + SQLAlchemy + Pydantic + auth middleware to wire up |
| `service-mesh` | Microservice cluster | `sv import` **is** the architecture: the compiler turns imports into HTTP stubs, the consumer auto-starts its providers, and env vars re-point services across hosts -- no OpenAPI codegen, no client SDKs |
| `py-package` | pip-installable wheel | `jac build --as wheel` with nothing beyond `jac.toml`; the wheel runs under the `jac` binary with **no `jaclang` runtime dependency** |
| `js-package` | npm tarball | Compiles to ES modules with **auto-generated `package.json` and `.d.ts` declarations**, consumable from any JS/TS project -- built with no Node.js installed |
| `web-app` | Full-stack web app | Backend, frontend, and data model **in one file**: `cl` code compiles to React, and the compiler writes every RPC and shares types across the boundary -- instead of two projects and five frameworks |
| `web-static` | Client-only page | `na {}` blocks compile to **WebAssembly with Jac's own wasm linker** (no emscripten); `jac build` emits a portable `index.html` that opens straight from disk |
| `desktop` 🧪 | Native desktop binary | The same app wrapped in the **OS webview** as one compiled binary -- no Electron, no Rust, no PyInstaller |
| `mobile` 🧪 | Android / iOS app | The same `cl` bundle wrapped by Capacitor, or true-native React Native via mobUI -- JS tooling runs on the bundled Bun, no Node.js |

The full cookbook, with a small working example of each: [What You Can Build](https://docs.jaseci.org/quick-guide/project-kinds/).

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
