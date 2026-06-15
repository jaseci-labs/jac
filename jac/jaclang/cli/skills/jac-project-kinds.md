---
name: jac-project-kinds
description: Choosing the right guides for what you're building - maps every Jac project kind (CLI, API service, microservices, full-stack, native binary, shared library, wasm, desktop, mobile, PyPI/npm packages) to its build verbs, required plugins, and the guides to load. Load FIRST when starting any new project or when unsure which guides apply.
---

Jac compiles one language to three runtimes - Python bytecode (server `sv`), JavaScript (client `cl`), and native machine code (`na`, which also targets WebAssembly). Every project kind is a combination of those blocks. Find your kind, run its verbs, load its guides (`jac guide <name>`).

**`jac run` is kind-aware.** Set `kind` under `[project]` in `jac.toml` (or let it be inferred from the entry-point codespace), and a bare `jac run` in the project does the right thing for that kind: *execute* runnable kinds (cli, native-app), *serve* server kinds (api-service, fullstack, ...), or *build* artifact kinds (native-binary, shared-library, pypi/npm packages). `jac run --show` prints the resolved plan (kind, action, and the equivalent primitive command) without running it. The explicit per-kind verbs in the table below remain the underlying primitives.

## Routing table

| Kind | What it is | Build / run | Plugins | Load these guides |
|---|---|---|---|---|
| CLI tool | Script/automation run from the terminal; graph persists in `.jac/data` between runs | `jac run tool.jac` | none | `jac-node-edge-patterns`, `jac-walker-patterns` |
| Native binary | Standalone zero-dependency executable via LLVM (restricted native subset, no Python imports) | `jac nacompile app.jac -o app` | none | `jac-native` |
| API service | Headless REST server; `walker:pub` / `def:pub` become `POST /walker/<name>` / `/function/<name>` endpoints; Swagger at `/docs` | `jac start api.jac --no_client` | none (jac-scale for k8s deploy) | `jac-sv-endpoints`, `jac-sv-persistence`, `jac-sv-auth`, `jac-sv-multi-user` |
| Microservices | Same code split into services via `sv import` (calls become HTTP RPCs; consumer auto-starts providers) | `jac start consumer.jac --port N`; `JAC_SV_<MOD>_URL` to split hosts | none | `jac-sv-microservices`, `jac-sv-endpoints`, `jac-sv-deploy` |
| Python package (PyPI) | pip-installable library or CLI tool; `def:pub` is the public API | `jac bundle` then `twine upload dist/*` | none | `jac-packaging`, `jac-impl-files` |
| npm package | Client component/function library for any JS/TS project (`.d.ts` included) | `jac bundle --target npm` then `npm publish` | none | `jac-packaging`, `jac-cl-components` |
| Shared library (C ABI) | `.so`/`.dylib`/`.dll` callable from C/C++/Rust/Go/ctypes; `:pub` is the export surface | `jac nacompile lib.jac --shared` (`--target macos\|windows` cross-builds) | none | `jac-native-shared`, `jac-native` |
| Full-stack app | Server + React UI in one project; `cl` code compiles to the browser bundle, RPC generated across the boundary | `jac create app --use fullstack`; `jac start --dev` | jac-client | `jac-fullstack-patterns`, `jac-cl-components`, `jac-sv-endpoints`, `jac-cl-routing` |
| In-browser native (wasm) | `na {}` block compiled to WebAssembly, driven by a `cl` page - native-speed compute client-side | `jac start` (emits `/static/main.wasm`) | jac-client | `jac-native-wasm`, `jac-cl-components` |
| Desktop app | The full-stack app wrapped in one nacompiled binary embedding the OS webview | `jac start --client desktop` / `jac build --client desktop` | jac-client + jac-desktop | `jac-desktop-app`, `jac-fullstack-patterns` |
| Mobile app (webview) | Client bundle wrapped by Capacitor for Android/iOS; frontend-only, talks to a separately deployed server | `jac setup mobile --platform android`; `jac build --client mobile` | jac-client (+ Android SDK / Xcode) | `jac-mobile-app`, `jac-cl-components` |

## Cross-cutting guides (any kind)

- **Always load `jac-core-cheatsheet`** (baseline syntax) and `jac-types` before writing Jac.
- Bootstrapping a project: `jac-scaffold`. Configuring it (`jac.toml`, deps, scripts, profiles): `jac-config`.
- Data modeling on the graph: `jac-node-edge-patterns` + `jac-walker-patterns`; typed state: `jac-has-fields`.
- LLM-powered functions in any kind: `jac-by-llm`. Calling Python libs / being called from Python: `jac-python-interop`. Parallelism: `jac-concurrency`.
- Client work beyond components: `jac-cl-organization`, `jac-cl-styling`, `jac-cl-auth`, `jac-cl-js-interop`, `jac-npm-packages` (consuming), `jac-shadcn-components`, `jac-shadcn-blocks`.
- Production server concerns: `jac-sv-deploy` (scale/k8s/secrets), `jac-sv-persistence` (schema evolution).

## The loop for every kind

1. Scaffold (`jac-scaffold`), then validate every edit with `jac check .`
2. Test with `jac test` - load `jac-testing` before writing tests
3. When anything misbehaves, load `jac-debugging` (diagnostic anatomy, stale-cache triage)
