# What You Can Build

Jac compiles one language to three runtimes -- Python bytecode (server, `sv`), JavaScript (client, `cl`), and native machine code (`na`) -- so the *same* skills produce a CLI tool, a REST API, a full-stack app, or a desktop/mobile build. This page is a cookbook: a **small, working example of each common thing you can build** with Jac today, plus the verbs that build and run it. Each one is a *combination* of a few building blocks, not a separate mode.

Every example below was run against the current toolchain. Install once and follow along:

```bash
pip install jaseci
```

## The recipes at a glance

Jac gives you three runtime targets -- server (`sv`), client (`cl`), and native (`na`) -- plus a few ways to **serve**, **package**, or wrap them in a **shell**. Everything below is a *combination* of those building blocks, not a separate mode. The grid shows which blocks each recipe uses; each recipe's exact command is in its section below.

Jac is also batteries-included -- it bundles LLVM, ships its own native linker, runs its own server, and auto-installs the JS runtime (`bun`) on demand. The only recipes needing an external toolchain are the ones wrapping a native OS shell, called out in the last column.

| Recipe | sv | cl | na | served | packaged | shell | requires |
|---|:--:|:--:|:--:|:--:|:--:|:--:|---|
| [CLI tool](#cli-tool) | ● | | | | | | -- |
| [Native binary](#native-binary) | | | ● | | | | -- |
| [API service](#api-service) | ● | | | ● | | | -- |
| [Microservices](#microservices) | ● ×N | | | ● | | | -- |
| [Python package (PyPI)](#python-package-pypi) | ● | | | | wheel | | twine¹ |
| [npm package (npmjs.com)](#npm-package) | | ● | | | npm | | npm³ |
| [Full-stack app](#full-stack-app) | ● | ● | | ● | | | -- |
| [Desktop app](#desktop-app) | ● | ● | | ● | | desktop | Tauri² |
| [Mobile app (webview)](#mobile-app-webview) | ◐ | ● | | | | mobile | Android SDK / Xcode |
| [Full-stack package](#on-the-roadmap) 🚧 | ● | ● | | | attach | | -- |
| [Mobile app (React Native)](#on-the-roadmap) 🚧 | ◐ | SDK | | | | RN | Android SDK / Xcode |

**Legend** -- ● uses this block · ◐ talks to a *remote* server (doesn't bundle one) · ×N replicated per service · 🚧 not yet wired end-to-end ([see roadmap](#on-the-roadmap)). Columns 2–7 are *composition* (what it's made of): **sv / cl / na** = which runtimes compile · **served** = exposes a REST API via `jac start` · **packaged** = produces a distributable artifact · **shell** = wrapped in a native desktop/mobile shell. The **requires** column is a different axis -- *setup cost*: toolchains you install yourself, excluding Jac plugins (jac-scale, jac-client, jac-desktop), which install through the Jac ecosystem.

<small>¹ Only to *upload* to PyPI; `jac bundle` itself needs nothing. &nbsp; ² Pulled in by the `jac-desktop` plugin via pip (no Rust); uses the OS webview. &nbsp; ³ Only to *publish* (`npm publish`); `jac bundle` builds the `.tgz` with no Node/npm.</small>

Read across a row and the composition is the point: a full-stack app is just a *service* plus a *client*; a desktop app is that plus a *shell*; microservices are a *service* replicated. The 🚧 rows aren't missing "kinds" -- they're capability combinations that aren't wired yet.

---

## Backend & CLI

### CLI tool

The simplest project: anything you run straight from the terminal -- scripts, automation, dev tools. A `.jac` file runs directly with the whole language and ecosystem available (it just needs Jac installed; to ship a self-contained binary instead, see [Native binary](#native-binary)). Jac is graph-native, so even a one-off script can model data as nodes and traverse them with a walker.

```jac
# hello.jac
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

!!! tip "`root` persists"
    The graph hanging off `root` is automatically saved between runs. Run it twice and you'll see the people accumulate -- that persistence is the same machinery that backs Jac servers, with no database to set up.

:octicons-arrow-right-24: Full tutorial: [Jac Fundamentals](../tutorials/language/basics.md) · [Graphs & Walkers](../tutorials/language/osp.md)

### Native binary

A `.na.jac` file compiles, through LLVM, to a **standalone, zero-dependency executable** you can ship to machines that have neither Jac nor Python installed -- like a `curl`-style single-binary tool. (Same command-line territory as a [CLI tool](#cli-tool), but the trade is reversed: ship-anywhere portability in exchange for the restricted native subset.) That subset requires a `with entry` block and allows no walkers/nodes/async and no Python imports.

```jac
# sum.na.jac
def compute_sum(n: int) -> int {
    total: int = 0;
    i: int = 1;
    while i <= n {
        total = total + i;
        i = i + 1;
    }
    return total;
}

with entry {
    result = compute_sum(10);
    print(f"Sum of 1 to 10: {result}");
}
```

```bash
jac nacompile sum.na.jac -o sum
./sum
```

```text
Sum of 1 to 10: 55
```

The result is a real native binary (a few KB here) you can ship without Python or Jac installed.

:octicons-arrow-right-24: Full tutorial: [Build a Chess Engine](../tutorials/native/chess.md) · Reference: [Native pathway](../reference/language/native-pathway.md)

### API service

A server with no frontend. Mark a walker `walker:pub` (or a function `def:pub`) and it becomes a REST endpoint automatically -- request bodies map onto the walker's `has` fields, and `report` becomes the JSON response.

```jac
# api.jac
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
jac start api.jac --no-client
```

`--no-client` skips all frontend bundling -- a pure JSON API. Walkers are exposed at `POST /walker/<name>`:

```bash
curl -X POST http://localhost:8000/walker/add_task \
  -H "Content-Type: application/json" -d '{"title": "Write docs"}'

curl -X POST http://localhost:8000/walker/list_tasks
```

Interactive API docs are served at `http://localhost:8000/docs` (Swagger) and a live graph view at `http://localhost:8000/graph`.

:octicons-arrow-right-24: Full tutorial: [Local API Server](../tutorials/production/local.md)

### Microservices

The same code runs as a monolith *or* as several independently-deployed services -- the only change is the `sv import` keyword. When both modules are server-context, the compiler turns the import into an HTTP client stub: calls become RPCs, but the source still reads like a normal import.

```jac
# math_service.jac  (the provider)
def:pub add(a: int, b: int) -> int {
    return a + b;
}

def:pub multiply(a: int, b: int) -> int {
    return a * b;
}
```

```jac
# calculator_service.jac  (the consumer)
sv import from math_service { add, multiply }

def:pub dot_product(a: list[int], b: list[int]) -> int {
    result = 0;
    for i in range(len(a)) {
        result = add(result, multiply(a[i], b[i]));  # each call is a POST over HTTP
    }
    return result;
}
```

With a `jac.toml` in the directory, one command brings up the whole cluster -- the consumer auto-starts every service it imports from:

```bash
jac start calculator_service.jac --port 8002

curl -X POST http://localhost:8002/function/dot_product \
  -H "Content-Type: application/json" -d '{"a": [1,2,3], "b": [4,5,6]}'
```

To split services across hosts, point each consumer at its providers with `JAC_SV_<MODULE>_URL` environment variables -- no source change. `jac setup microservice --add <file>` records which files become services for production deploys.

:octicons-arrow-right-24: Full tutorial: [Microservices with `sv import`](../tutorials/production/microservices.md)

### Python package (PyPI)

A reusable library -- no entry point -- packaged as a standard pip wheel. Any `def:pub` is part of the public API.

```jac
# greetlib.jac
def:pub greet(name: str) -> str {
    return f"Hello, {name}!";
}
```

```toml
# jac.toml
[project]
name = "greetlib"
version = "0.1.0"
description = "A tiny Jac library"
```

```bash
jac bundle
# → dist/greetlib-0.1.0-py3-none-any.whl
```

Upload it with `twine`, then `pip install greetlib` anywhere. The wheel ships your compiled modules and lists `jaclang` as a runtime dependency.

:octicons-arrow-right-24: Reference: [Publishing](../reference/publishing.md)

### npm package

The client-side counterpart to the Python package: a `cl` component (or function) library published to [npm](https://www.npmjs.com) so any JavaScript or TypeScript project can `npm install` it -- whether or not they use Jac. The same `jac.toml` drives it; `--target npm` compiles your client modules to ES-module JavaScript, generates `package.json`, and emits `.d.ts` TypeScript declarations.

```jac
# greetui/index.cl.jac
def:pub Greeting(name: str) -> JsxElement {
    return <h1>Hello, {name}!</h1>;
}
```

```toml
# jac.toml
[project]
name = "greetui"
version = "0.1.0"
description = "A tiny Jac component library"

[project.include]
packages = ["greetui"]

[npm]
name = "@myscope/greetui"   # optional scoped npm name
```

```bash
jac bundle --target npm
# → dist/myscope-greetui-0.1.0.tgz   (jac bundle --target all builds the wheel too)
```

The generated `package.json` wires in `@jaseci/runtime` automatically for JSX/reactive code. Upload it with `npm publish` (Jac builds the tarball but doesn't upload, exactly like `twine` for wheels).

!!! note "npm packages must be standalone client code"
    A module that crosses a server boundary (an `sv` import or call) can't run from a plain `npm install`, so `jac bundle --target npm` rejects it with a clear error. Keep server-coupled code in your app, not in the published library.

:octicons-arrow-right-24: Reference: [Publishing to npm](../reference/publishing.md#publishing-to-npm-npmjsorg)

---

## Full-stack & apps

### Full-stack app

The headline case: backend, frontend, and data model in **one file**. Code in a `cl` block (or `.cl.jac` file) compiles to a React/JSX bundle for the browser; everything else compiles to Python for the server. The compiler generates the HTTP calls between them -- `await add_todo(...)` in the client is a real RPC to the server function, with types shared across the boundary.

```jac
# main.jac
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

```toml
# jac.toml
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

[plugins.client]
```

```bash
jac start          # production server
jac start --dev    # hot-module reload while you edit
```

Open [http://localhost:8000](http://localhost:8000). No database, no separate frontend project, no glue code.

:octicons-arrow-right-24: Full tutorial: [Full-Stack Project Setup](../tutorials/fullstack/setup.md)

### Desktop app

Wrap the *same* full-stack app in a native desktop window. Jac uses **PyTauri** (Python, no Rust toolchain): your client bundle renders in the webview and your server runs as a frozen sidecar binary.

```bash
pip install jac-desktop      # adds the "desktop" client target
jac setup desktop            # one-time scaffold (src-pytauri/)

jac start --client desktop --dev      # develop with live reload
jac build --client desktop            # build the app
```

Window title, size, and bundled plugins are configured under `[plugins.desktop]` in `jac.toml`. Builds are per-OS (`--platform windows|macos|linux`).

:octicons-arrow-right-24: Full tutorial: [Desktop App](../tutorials/fullstack/desktop.md)

### Mobile app (webview)

Ship the same client bundle to Android/iOS via **Capacitor**, which wraps it in a native webview. The mobile app is the *frontend only* -- it talks to your Jac server over HTTP, so deploy the backend separately (e.g. as an [API service](#api-service)).

```bash
# prerequisites: Node.js; Android: JDK + Android SDK; iOS (macOS): Xcode
jac setup mobile --platform android    # one-time scaffold (android/)

jac start main.jac --client mobile --dev          # live reload on device/emulator
jac build --client mobile --platform android      # → android/.../app-debug.apk
```

Use `--platform ios` on macOS to produce an Xcode project. App name and id are set under `[plugins.client.mobile]`.

:octicons-arrow-right-24: Full tutorial: [Mobile App](../tutorials/fullstack/mobile.md)

---

## On the roadmap

These aren't missing "kinds" -- they're **capability combinations that aren't wired end-to-end yet**. Here's the honest status and the closest thing you can do today.

- **Full-stack package** (`sv` + `cl` + *attach*) -- An installable feature that brings its own routes, UI components, and data models into your app (think "drop in payments and get a checkout button + endpoints + models"). `sv import` composes *services* over HTTP, but there's no attachable in-process package yet. This needs a no-entry "package" artifact and conflict-resolution semantics across the three runtimes.
- **Mobile app (React Native)** (a new RN *shell*) -- The mobile shell is Capacitor (webview) only. A true React Native shell would need a Jac → RN component path and a typed client SDK rather than the DOM/JSX bundle.

!!! info "Want to follow the design?"
    The unified build/artifact work that would close these gaps is tracked in the Jac repo's `jac build` / `.jab` proposals.
