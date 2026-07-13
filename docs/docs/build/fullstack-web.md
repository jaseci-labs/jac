# I like to build … Full-stack web apps

Backend, frontend, and data model in one language -- the compiler generates the HTTP calls between them and shares types across the boundary. Ship a server-backed app or a client-only static page. These map to the `web-app` and `web-static` [project kinds](../quick-guide/project-kinds.md).

## Your 5-minute quick win {#web-app}

Code in a `cl` block compiles to a React/JSX bundle for the browser; everything else compiles to Python for the server. `await add_todo(...)` in the client is a real RPC to the server function:

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

```bash
jac start          # production server
jac start --dev    # hot-module reload while you edit
```

Open [http://localhost:8000](http://localhost:8000). No database, no separate frontend project, no glue code. See the [Build Anything recipe](../quick-guide/project-kinds.md#full-stack-app) for the full `jac.toml`.

## Client-only & in-browser native {#web-static}

Set `kind = "web-static"` for an app with **no backend** -- a pure `cl` page that `jac build` emits as a portable, self-contained `dist/`. This is also the home of *in-browser native compute*: an `na {}` block compiles to **WebAssembly** and runs client-side at native speed (a game loop, a simulation, a hot inner loop), driven by the `cl` page with no server round-trip -- Jac's own WebAssembly linker turns it into an instantiable module.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces & the client/server boundary
- **Build it for real** → [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md) (the marquee tutorial), then the full-stack series: [Setup](../tutorials/fullstack/setup.md) · [Components](../tutorials/fullstack/components.md) · [State](../tutorials/fullstack/state.md) · [Backend](../tutorials/fullstack/backend.md) · [Auth](../tutorials/fullstack/auth.md) · [Routing](../tutorials/fullstack/routing.md)
- **Look it up** → [jac-client reference](../reference/plugins/jac-client.md) · [Client-only apps](../reference/plugins/jac-client.md#client-only-apps) · [WebAssembly in the browser](../tutorials/native/wasm.md)
- **Ship it** → [Local server](../tutorials/production/local.md) · [Kubernetes](../tutorials/production/kubernetes.md)

## Going further

- Add AI to your app → [AI agents & LLM apps](ai-agents.md)
- Wrap it as a native window or mobile app → [Desktop & mobile apps](desktop-mobile.md)
- Publish a component library → [Reusable libraries & packages](libraries.md#js-package)
