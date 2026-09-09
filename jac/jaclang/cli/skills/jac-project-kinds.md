---
name: jac-project-kinds
description: Choose a Jac project kind and its build commands. Use when starting a project or selecting task-specific guides.
---

Jac compiles one language to three runtimes - Python bytecode (server), JavaScript (client), and native machine code (which also targets WebAssembly). Every project kind is a combination of those codespaces. Placement is inferred: JSX/npm imports mark code client and references pull helpers along, server is the default, and native is seeded by extern C declarations; overrides live in `jac.toml` under `[placement.pins]` (see `jac-codespaces`). Find your kind, run its verbs, load its guides (`jac guide <name>`).

**`jac create` is kind-aware.** Scaffold any kind with `jac create <name> --kind <kind>` (e.g. `--kind service`, `--kind native-binary`, `--kind web-app`). It stamps `[project] kind` into `jac.toml`, lays the entry-point in the right codespace, and (unless `--skip`) runs a full `jac install` so Python and npm deps are ready. `jac create --list` lists the available kinds. See `jac-scaffold`.

**`jac run` is kind-aware.** With `kind` set under `[project]` in `jac.toml` (stamped by `jac create`, or inferred from the entry-point codespace), a bare `jac run` in the project does the right thing for that kind: *execute* runnable kinds (cli, cli-native), *serve* server kinds (service, web-app, ...), or *build* artifact kinds (native-binary, native-lib, py/js packages). `jac run --show` prints the resolved plan (kind, action, and the equivalent primitive command) without running it. The explicit per-kind verbs in the table below remain the underlying primitives. Each kind also fixes what its client renders (`web-app`, `web-static`, `desktop`, `js-package` → React DOM; `mobile` → native views through `@jac/mobui`; the rest have no client) and whether it **has a server** (`service`, `service-mesh`, `web-app`).

**One project can hold several apps.** A `jac.toml` with `[apps.<name>]` tables (each with its own `kind`, `path`/`entry-point`, `platform`, `route`) is a **workspace**: a web-app, a mobile app, a cli and file-rooted service apps over one shared `core/`, type-checked together by `jac check` and addressed by name - `jac run web`, `jac build mobile`, `jac test cli`, `jac build --all`. Modules under no app root are shared; an app reaches what another app owns through a compiler-generated bridge, colocated by default and split by `--fleet` / deploy. `jac create --app <name> --kind <kind>` adds an app; `jac create <name> --awesome` scaffolds the flagship (jaclang.org: web + mobile + cli + two service apps). Config: `jac-config`; the bridge: `jac-sv-microservices`.

## Routing table

| Kind | What it is | Build / run | Load these guides |
|---|---|---|---|
| CLI tool | Script/automation run from the terminal; graph persists in `.jac/data` between runs | `jac run tool.jac` | `jac-node-edge-patterns`, `jac-walker-patterns` |
| Native binary | Standalone zero-dependency executable via LLVM (restricted native subset, no Python imports) | `jac build --native app.jac -o app` | `jac-native` |
| API service | Headless REST server; `walker:pub` / `def:pub` become `POST /walker/<name>` / `/function/<name>` endpoints; Swagger at `/docs` | `jac run --no-client api.jac` | `jac-sv-endpoints`, `jac-sv-persistence`, `jac-sv-auth`, `jac-sv-multi-user` |
| Service apps | Same code split into apps via `[apps.<name>] kind = "service"` in jac.toml (imports of what another app owns become typed-async bridge stubs; `jac run` colocates providers, `--fleet` splits them) | `jac create --app <name> --kind service`; `jac run --port N <app>` / `--fleet`; `JAC_APP_<APP>_URL` to split hosts | `jac-sv-microservices`, `jac-sv-endpoints`, `jac-sv-deploy` |
| Python package (PyPI) | pip-installable library or CLI tool; `def:pub` is the public API | `jac build --as wheel` then `twine upload dist/*` | `jac-packaging`, `jac-impl-files` |
| npm package | Client component/function library for any JS/TS project (`.d.ts` included) | `jac build --as npm` then `npm publish` | `jac-packaging`, `jac-cl-components` |
| Shared library (C ABI) | `.so`/`.dylib`/`.dll` callable from C/C++/Rust/Go/ctypes; `:pub` is the export surface | `jac build --native lib.jac --lib` (`--target macos\|windows` cross-builds) | `jac-native-shared`, `jac-native` |
| Full-stack app | Server + React UI in one project; client code (inferred from JSX/npm imports) compiles to the browser bundle, RPC generated across the boundary | `jac create app --kind web-app`; `jac run --dev` | `jac-fullstack-patterns`, `jac-cl-components`, `jac-sv-endpoints`, `jac-cl-routing` |
| In-browser native (wasm) | native code compiled to WebAssembly, driven by a client page - native-speed compute client-side | `jac run` (emits `/static/main.wasm`) | `jac-native-wasm`, `jac-cl-components` |
| Desktop app | The full-stack app wrapped in one nacompiled binary embedding the OS webview (`kind = "desktop"`; `[desktop] engine = "cef"` swaps in Chromium) | `jac run <app>` / `jac build <app>` | `jac-desktop-app`, `jac-fullstack-patterns` |
| Mobile app | mobUI app (`kind = "mobile"`) compiled to native views through React Native; frontend-only, bridges to a separately served app; also runs on the web via react-native-web (`--platform web`) | `jac setup <app>`; `jac run --dev <app>`; `jac build <app> --platform android` (needs Android SDK / Xcode) | `jac-mobui`, `jac-mobile-app`, `jac-cl-components` |
| PWA | A `web-app` with a `[client.pwa]` table in `jac.toml`: `jac build` adds the manifest, service worker, icons and install banner to the bundle | `jac setup <app>` (placeholder `pwa_icons/`); `jac build <app>` | `jac-fullstack-patterns` |

## Cross-cutting guides (any kind)

- **Always load `jac-core-cheatsheet`** (baseline syntax) and `jac-types` before writing Jac.
- Where code runs - inferred client/server/native placement, `[placement.pins]` overrides: `jac-codespaces`.
- Bootstrapping a project: `jac-scaffold`. Configuring it (`jac.toml`, deps, scripts, profiles): `jac-config`.
- Data modeling on the graph: `jac-node-edge-patterns` + `jac-walker-patterns`; typed state: `jac-has-fields`.
- LLM-powered functions in any kind: `jac-by-llm`. Calling Python libs / being called from Python: `jac-python-interop`. Parallelism: `jac-concurrency`.
- Client work beyond components: `jac-cl-organization`, `jac-cl-styling`, `jac-cl-auth`, `jac-cl-js-interop`, `jac-npm-packages` (consuming), `jac-shadcn-components`, `jac-shadcn-blocks`.
- Production server concerns: `jac-sv-deploy` (scale/k8s/secrets), `jac-sv-persistence` (schema evolution).

## The loop for every kind

1. Scaffold (`jac-scaffold`), then validate every edit with `jac check .`
2. Test with `jac test` - load `jac-testing` before writing tests
3. When anything misbehaves, load `jac-debugging` (diagnostic anatomy, stale-cache triage)

Deep dives bundled with the CLI: `jac guide tutorials/production/local` (serve + auth over HTTP, worked end to end), `jac guide reference/cli` (every command and flag).
