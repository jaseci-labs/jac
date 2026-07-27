# I like to build … Full-stack web apps

Backend, frontend, and data model in one language -- the compiler generates the HTTP calls between them and shares types across the boundary. Ship a server-backed app or a client-only static page. These map to the `web-app` and `web-static` [project kinds](../quick-guide/project-kinds.md).

## Your 5-minute quick win {#web-app}

The client/server split is **inferred**: a declaration carrying JSX (plus anything it uses) compiles to a React/JSX bundle for the browser; everything else compiles to Python for the server. Explicit markers like the `cl` prefix below are optional overrides -- here the JSX alone would place `app` on the client. `await add_todo(...)` in the client is a real RPC to the server function:

```jac
# main.jac
node Todo { has title: str, done: bool = False; }

def:pub add_todo(title: str) -> Todo {
    todo = Todo(title=title);
    root ++> todo;
    return todo;
}

def:pub get_todos -> list[Todo] { return [root-->][?:Todo]; }

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
            placeholder="Add a todo..." />
        <button onClick={add}>Add</button>
        {[<p key={jid(t)}>{t.title}</p> for t in todos]}
    </div>;
}
```

With a `jac.toml` declaring your npm deps and `[client]`:

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

[client]
```

```bash
jac start          # production server
jac start --dev    # hot-module reload while you edit
```

Open [http://localhost:8000](http://localhost:8000). No database, no separate frontend project, no glue code.

## Client-only & in-browser native {#web-static}

Set `kind = "web-static"` for an app with **no backend** -- a pure `cl` page that `jac build` emits as a portable, self-contained `dist/`. This is also the home of *in-browser native compute*: an `na {}` block compiles to **WebAssembly** and runs client-side at native speed (a game loop, a simulation, a hot inner loop), driven by the `cl` page with no server round-trip. One module holds both halves:

```jac
# main.jac
na {
    """Count primes below n -- a tight integer loop, compiled to WebAssembly."""
    def count_primes(n: int) -> int {
        count = 0;
        i = 2;
        while i < n {
            is_prime = True;
            j = 2;
            while j < i {
                if i % j == 0 { is_prime = False; break; }
                j += 1;
            }
            if is_prime { count += 1; }
            i += 1;
        }
        return count;
    }
}

cl {
    def:pub app -> JsxElement {
        has answer: str = "computing...";
        async can with entry {
            res: any = await WebAssembly.instantiateStreaming(
                fetch("/static/main.wasm"), {"env": {"puts": lambda { return 0; }}}
            );
            wasm: any = res.instance.exports;
            wasm.__jac_glob_init();
            # an i64 crosses the JS boundary as a BigInt; format it straight to text
            answer = f"{wasm.count_primes(BigInt(20000))}";
        }
        return <div>
            <h1>Native compute in the browser</h1>
            <p>{"primes below 20000 (computed in wasm): "}<b>{answer}</b></p>
        </div>;
    }
}
```

It uses the same `jac.toml` as the full-stack quick win above (React deps + `[client]`), with `kind = "web-static"` under `[project]`.

```bash
jac start          # builds the cl bundle + na->wasm, serves on http://localhost:8000
jac start --dev    # same, with hot reload
jac build          # portable, self-contained dist in .jac/client/dist/
```

Because a `web-static` project has no server, `jac start` serves the build with a **minimal static server** (no API server, auth, or database) and `jac build` emits a **portable `index.html`** with its JS/CSS inlined, so a pure `cl` page opens directly from disk (`file://`). An app that fetches `/static/main.wasm` at runtime, like this one, must be *served* (the browser can't fetch the module over `file://`). See [Client-only apps](../reference/plugins/jac-client.md#client-only-apps).

`jac start` compiles the `na` block to `/static/main.wasm` as part of the client build -- no emscripten and no `wasm-ld`; Jac's own WebAssembly linker turns the object into an instantiable module -- and the page fetches it on mount:

```text
primes below 20000 (computed in wasm): 2262
```

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces & the client/server boundary
- **Build it for real** → [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md) (the marquee tutorial), then the full-stack series: [Setup](../tutorials/fullstack/setup.md) · [Components](../tutorials/fullstack/components.md) · [State](../tutorials/fullstack/state.md) · [Backend](../tutorials/fullstack/backend.md) · [Auth](../tutorials/fullstack/auth.md) · [Routing](../tutorials/fullstack/routing.md)
- **Look it up** → [jac-client reference](../reference/plugins/jac-client.md) · [Client-only apps](../reference/plugins/jac-client.md#client-only-apps) · [WebAssembly in the browser](../tutorials/native/wasm.md)
- **Ship it** → [Local server](../tutorials/production/local.md) · [Kubernetes](../tutorials/production/kubernetes.md)

## Going further

- Add AI to your app → [AI agents & LLM apps](ai-agents.md)
- Wrap it as a native window or mobile app → [Desktop & mobile apps](desktop-mobile.md)
- Publish a component library → [Reusable libraries & packages](libraries.md#js-package)
