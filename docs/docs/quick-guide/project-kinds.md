# What You Can Build

Jac compiles one language to three runtimes -- Python bytecode (server, `sv`), JavaScript (client, `cl`), and native machine code (`na`, which also compiles to in-browser WebAssembly) -- so the *same* skills produce a CLI tool, a REST API, a full-stack app, a desktop/mobile build, native compute that runs in the browser, or a C-callable shared library. This page is the hub: the composition grid below shows what each kind is made of, and every kind links to its guided **"I like to build…" track**, which carries the working recipe and a curated path onward. Each one is a *combination* of a few building blocks, not a separate mode.

Install once and follow any track:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

This installs the self-contained `jac` binary -- no Python, pip, or uv required.

!!! tip "`jac run` is kind-aware"
    Set `kind` under `[project]` in `jac.toml` (or let it be inferred from the entry-point's codespace), and a bare `jac run` does the right thing for that kind: **execute** runnable kinds (`cli`, `cli-native`), **serve** server kinds (`service`, `web-app`, ...), or **build** artifact kinds (`native-binary`, `native-lib`, `py-package`, `js-package`). `jac run --show` prints the resolved plan and the equivalent primitive command without running it.

## The recipes at a glance

Jac gives you three runtime targets -- server (`sv`), client (`cl`), and native (`na`) -- plus a few ways to **serve**, **package**, or wrap them in a **shell**. Everything below is a *combination* of those building blocks, not a separate mode. The grid shows which blocks each recipe uses; each recipe name links to the track that owns its code.

Jac is also batteries-included -- it bundles LLVM, ships its own native linker, runs its own server, and auto-installs the JS runtime (`bun`) on demand. The only recipes needing an external toolchain are the ones wrapping a native OS shell, called out in the last column.

| Recipe | status | sv | cl | na | served | packaged | shell | requires |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|---|
| [CLI tool](../build/cli-and-native.md#cli) | ✅ | ● | | | | | | -- |
| [Native CLI tool](../build/cli-and-native.md#cli-native) | ✅ | | | ● | | | | -- |
| [Native binary](../build/cli-and-native.md#native-binary) | ✅ | | | ● | | | | -- |
| [API service](../build/backend-apis.md#service) | ✅ | ● | | | ● | | | -- |
| [Microservices](../build/backend-apis.md#service-mesh) | ✅ | ● ×N | | | ● | | | -- |
| [Python package (PyPI)](../build/libraries.md#py-package) | ✅ | ● | | | | wheel | | twine¹ |
| [npm package (npmjs.com)](../build/libraries.md#js-package) | ✅ | | ● | | | npm | | npm³ |
| [Shared library (C ABI)](../build/libraries.md#native-lib) | ✅ | | | ● | | .so/.dll | | -- |
| [Full-stack app](../build/fullstack-web.md#web-app) | ✅ | ● | ● | | ● | | | -- |
| [Static / in-browser app](../build/fullstack-web.md#web-static) | ✅ | | ● | ● | ● | | | -- |
| [Desktop app](../build/desktop-mobile.md#desktop) | 🧪⁴ | ● | ● | | ● | | desktop | WebKit² |
| [Mobile app (webview)](../build/desktop-mobile.md#mobile) | 🧪⁵ | ◐ | ● | | | | mobile | Android SDK / Xcode |
| [Mobile app (React Native)](../build/desktop-mobile.md#react-native) | 🧪⁶ | ◐ | ● | | | | react-native | Android SDK / Xcode |
| [Full-stack package](#on-the-roadmap) | 🚧 | ● | ● | | | attach | | -- |

**Legend** -- ● uses this block · ◐ talks to a *remote* server (doesn't bundle one) · ×N replicated per service. **status**: ✅ shipping · 🧪 beta (works, with caveats footnoted below) · 🚧 not yet wired end-to-end ([see roadmap](#on-the-roadmap)). Columns 2–7 are *composition* (what it's made of): **sv / cl / na** = which runtimes compile (`na` to a host binary, or to WebAssembly for [in-browser native](#in-browser-native-wasm)) · **served** = hosted by `jac start` (exposing any `sv` walkers/functions as a REST API) · **packaged** = produces a distributable artifact · **shell** = wrapped in a native desktop/mobile shell. The **requires** column is a different axis -- *setup cost*: toolchains you install yourself, excluding the built-in `scale` subsystem (which ships with `jaclang` core; its optional deploy deps are pulled per-project via `[scale.*]` config + `jac install`) and the full-stack client/desktop framework (which also ships with `jaclang` core).

<small>¹ Only to *upload* to PyPI; `jac build --as wheel` itself needs nothing. &nbsp; ² The desktop target ships with `jaclang` core (no Rust); it embeds the OS webview. On Linux you need the WebKitGTK system libraries (a bundled helper script installs them). &nbsp; ³ Only to *publish* (`npm publish`); `jac build --as npm` builds the `.tgz` with no Node/npm. &nbsp; ⁴ The binary renders your `cl` UI and runs `sv` walkers in-process, with HMR dev mode; per-OS installers/code-signing remain open ([#6436](https://github.com/jaseci-labs/jaseci/issues/6436)). &nbsp; ⁵ Frontend-only Capacitor wrapper -- the app talks to a Jac server you deploy separately. &nbsp; ⁶ Beta React Native (Expo/Metro) frontend built from a mobUI source tree (`@jac/mobui` primitives, no HTML) that also compiles for the web; it talks to a Jac server you deploy separately.</small>

Read across a row and the composition is the point: a full-stack app is just a *service* plus a *client*; in-browser native swaps the server for an `na` module compiled to wasm; a desktop app is a full-stack app plus a *shell*; microservices are a *service* replicated. The 🚧 rows aren't missing "kinds" -- they're capability combinations that aren't wired yet.

## Ship it: one file or one executable

Whatever you build, two universal projections turn it into something you can hand to someone else.

**A sealed app bundle (`.jab`)** -- a bare `jac build` type-checks the whole project (fail-closed) and emits one self-describing `.jab`: client dist, serve manifest, and native binaries baked in and hash-verified. Any machine with Jac installed runs or serves it with zero live compilation, kind-aware:

```bash
jac build                  # -> dist/<app>.jab
jac run dist/<app>.jab     # cli kinds execute
jac start dist/<app>.jab   # servable kinds production-serve
```

**A self-contained executable** -- `jac build --as binary` appends that same sealed `.jab` onto a copy of the `jac` launcher, producing one file that carries the full runtime. Hand it to a machine with no Jac, no Python, no Node:

```bash
jac build --as binary      # -> one executable, full runtime included
```

How is `--as binary` different from the [Native binary](#native-binary) recipe? `--as native` compiles the restricted `na` subset through LLVM into a small, dependency-free binary. `--as binary` packages *any* app -- walkers, Python imports, a full web client -- with the runtime included; the trade is a larger file. Details and the other projections (wheel, npm, source): [`jac build`](../reference/cli/index.md#jac-build).

---

## Backend & CLI

### CLI tool

The simplest project: anything you run straight from the terminal -- scripts, automation, dev tools. A `.jac` file runs directly with the whole language and ecosystem available, and because Jac is graph-native, even a one-off script can model data as nodes, traverse them with a walker, and keep its `root` graph between runs with no database.

:octicons-arrow-right-24: Recipe & guided path: [CLI tools & native binaries](../build/cli-and-native.md#cli) · Full tutorial: [Jac Fundamentals](../tutorials/language/basics.md)

### Native binary

A `.na.jac` file compiles, through LLVM, to a **standalone, zero-dependency executable** you can ship to machines that have neither Jac nor Python installed -- like a `curl`-style single-binary tool. Same command-line territory as a [CLI tool](#cli-tool), with the trade reversed: ship-anywhere portability in exchange for the restricted native subset. To ship a *full* app as one executable instead, see [Ship it](#ship-it-one-file-or-one-executable).

:octicons-arrow-right-24: Recipe & guided path: [CLI tools & native binaries](../build/cli-and-native.md#native-binary) · Full tutorial: [Build a Chess Engine](../tutorials/native/chess.md)

### API service

A server with no frontend. Mark a walker `walker:pub` (or a function `def:pub`) and it becomes a REST endpoint automatically -- request bodies map onto the walker's `has` fields, `report` becomes the JSON response, Swagger docs are served at `/docs`, and a live graph view at `/graph`.

:octicons-arrow-right-24: Recipe & guided path: [Backend APIs & services](../build/backend-apis.md#service) · Full tutorial: [Local API Server](../tutorials/production/local.md)

### Microservices

The same code runs as a monolith *or* as several independently-deployed services -- the only change is the `sv import` keyword. When both modules are server-context, the compiler turns the import into an HTTP client stub: calls become RPCs, but the source still reads like a normal import.

:octicons-arrow-right-24: Recipe & guided path: [Backend APIs & services](../build/backend-apis.md#service-mesh) · Full tutorial: [Microservices with `sv import`](../tutorials/production/microservices.md)

### Python package (PyPI)

A reusable library -- no entry point -- packaged as a standard pip wheel with `jac build --as wheel`. Any `def:pub` is part of the public API, and the wheel runs under the `jac` binary with no `jaclang` runtime dependency.

:octicons-arrow-right-24: Recipe & guided path: [Reusable libraries & packages](../build/libraries.md#py-package) · Reference: [Publishing](../reference/publishing.md)

### npm package

The client-side counterpart to the Python package: a `cl` component (or function) library published to [npm](https://www.npmjs.com) so any JavaScript or TypeScript project can `npm install` it -- whether or not they use Jac. `jac build --as npm` compiles your client modules to ES-module JavaScript, generates `package.json`, and emits `.d.ts` TypeScript declarations.

:octicons-arrow-right-24: Recipe & guided path: [Reusable libraries & packages](../build/libraries.md#js-package) · Reference: [Publishing to npm](../reference/publishing.md#publishing-to-npm-npmjsorg)

### Shared library (C ABI)

The native counterpart to the [Python](#python-package-pypi) and [npm](#npm-package) packages: an `na` module compiled to a **C-ABI shared library** (`.so` / `.dylib` / `.dll`) that *any* language with a C FFI -- C, C++, Rust, Go (`cgo`), Python (`ctypes`) -- can link or `dlopen`. It's the mirror image of `import from "lib.so"` (calling C *from* Jac): here you expose Jac *to* C.

:octicons-arrow-right-24: Recipe & guided path: [Reusable libraries & packages](../build/libraries.md#native-lib) · Reference: [Native pathway -- Shared libraries](../reference/language/native-pathway.md#shared-libraries-c-abi)

---

## Full-stack & apps

### Full-stack app

The headline case: backend, frontend, and data model in **one file**. The compiler infers the split: declarations carrying JSX or npm imports (plus whatever they use) compile to a React/JSX bundle for the browser; everything else compiles to Python for the server. The compiler generates the HTTP calls between the two -- an `await`ed server call in the client is a real RPC, with types shared across the boundary.

:octicons-arrow-right-24: Recipe & guided path: [Full-stack web apps](../build/fullstack-web.md#web-app) · Full tutorial: [Full-Stack Project Setup](../tutorials/fullstack/setup.md)

### In-browser native (wasm)

The `na` runtime's other target: rather than a host binary, an `na {}` block compiles to **WebAssembly** and runs *in the browser*, driven by a `cl` page -- native-speed compute (a game loop, a simulation, a hot inner loop) executing client-side with no server round-trip. It's the mirror image of a [full-stack app](#full-stack-app): there the heavy lifting runs on the server (`sv`); here it runs in the browser (`na` -> wasm), with no emscripten and no `wasm-ld` -- Jac's own WebAssembly linker does the wiring.

:octicons-arrow-right-24: Recipe & guided path: [Full-stack web apps](../build/fullstack-web.md#web-static) · Full example: [raylib cube shooter (web)](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/examples/raylib_shooter/web)

### Desktop app

Wrap the *same* full-stack app in a native desktop window. Jac compiles your `cl` UI into **one `jac nacompile`d binary that embeds the OS webview** (WebKitGTK / WKWebView / WebView2) - no Rust toolchain, no PyInstaller, no separate process. The `desktop` target ships with `jaclang` core.

:octicons-arrow-right-24: Recipe & guided path: [Desktop & mobile apps](../build/desktop-mobile.md#desktop) · Full tutorial: [Desktop App](../tutorials/fullstack/desktop.md)

### Mobile app (webview)

Ship the same client bundle to Android/iOS via **Capacitor**, which wraps it in a native webview. The mobile app is the *frontend only* -- it talks to your Jac server over HTTP, so deploy the backend separately (e.g. as an [API service](#api-service)).

:octicons-arrow-right-24: Recipe & guided path: [Desktop & mobile apps](../build/desktop-mobile.md#mobile) · Full tutorial: [Mobile App](../tutorials/fullstack/mobile.md)

### Mobile app (React Native)

Ship a **true native** mobile app (Android + iOS) using [React Native](https://reactnative.dev/), with platform-native views rather than a webview. A React Native app is a **mobUI** project: one source tree using Jac's `@jac/mobui` component vocabulary (`View`, `Text`, `Pressable`, ...) that compiles to both web and native. This is the *frontend only* -- it talks to your Jac server over HTTP.

:octicons-arrow-right-24: Recipe & guided path: [Desktop & mobile apps](../build/desktop-mobile.md#react-native) · Full reference: [React Native target](../reference/plugins/jac-client.md#react-native-target-beta)

---

## On the roadmap

These aren't missing "kinds" -- they're **capability combinations that aren't wired end-to-end yet**. Here's the status, stated plainly, and the closest thing you can do today.

- **Full-stack package** (`sv` + `cl` + *attach*) -- An installable feature that brings its own routes, UI components, and data models into your app (think "drop in payments and get a checkout button + endpoints + models"). `sv import` composes *services* over HTTP, but there's no attachable in-process package yet. This needs a no-entry "package" artifact and conflict-resolution semantics across the three runtimes.

!!! info "Want to follow the design?"
    The unified `jac build` verb and the sealed `.jab` artifact have shipped ([see Ship it](#ship-it-one-file-or-one-executable)). What remains for this row is the attachable *package* form: a no-entry `.jab` a host app can mount, plus its conflict-resolution semantics, tracked in the Jac repo's proposals and issues.
