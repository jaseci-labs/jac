# Cross-Codespace & Foreign Interop

## Overview

Jac compiles one source language to three first-class **codespaces** --
**`sv`** (server / Python), **`cl`** (client / JavaScript), and **`na`**
(native / LLVM) -- and a single `.jac` file may mix all three. Whenever a
call crosses from one codespace into another, or out to a foreign runtime
(CPython, C, or a WebAssembly host), the compiler has to *bridge* the gap:
discover the boundary, agree on a wire format, and synthesise the glue on
both sides.

This document is the reference for every one of those boundaries. It
assumes the codespace model from
[Compiler Architecture](compiler_architecture.md) -- read that first if the
terms `CodeContext`, `EsastGenPass`, `NaIRGenPass`, or "coercion" are new.
Here we go one level deeper: the *full* interop matrix, the mechanism behind
each cell, the marshalling format, and how desktop apps stitch several
boundaries into a single shippable binary.

### Two kinds of boundary

Every interop edge is one of two fundamentally different things:

- **Free boundaries** -- both sides live in the *same* runtime and address
  space, so a call is a direct function call and a value is passed by
  reference with no copy. Same-codespace calls (`sv→sv`, `cl→cl`, `na→na`)
  and Jac↔Python (`sv↔py`) are free.
- **Marshalled boundaries** -- the two sides are different runtimes
  (CPython ↔ V8, CPython ↔ machine code, machine code ↔ a wasm host). A call
  becomes an RPC or an FFI thunk, and every value that crosses must be
  *serialised* into a representation both sides understand. `cl↔sv`,
  `sv↔na`, `na↔C`, `na↔cl`, and the opt-in `sv→sv` microservice split are
  marshalled.

The compiler decides which is which automatically. Two analysis passes do
the discovery:

- **`BoundaryAnalysisPass`** detects an explicitly-tagged cross-runtime
  import (`sv import` inside a `.cl.jac`, a `clib` import in native code,
  etc.) and re-reads the *provider* module's AST to extract the public
  surface -- walker `has`-fields, `def` signatures, struct layouts -- into an
  `InteropBinding`.
- **`InteropAnalysisPass`** walks call sites, records the caller's and
  callee's `CodeContext` plus the boundary types, and accumulates them into
  an `InteropManifest`.

Both write their results into the schemas in
[`jac0core/codeinfo.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/codeinfo.jac).
Each backend codegen pass then reads that manifest and emits *its half* of
every bridge it participates in. No global "target" flag exists -- selection
is per-node, driven entirely by each node's `code_context` tag.

---

## The full interop matrix

The three codespaces give nine ordered pairs; the three same-codespace
pairs are free, the six crossings are marshalled. Two external runtimes
(CPython for Python interop, and C / a wasm host for foreign FFI) add the
remaining rows.

| # | Direction | Boundary kind | Mechanism | What crosses | Synthesised by |
|---|-----------|---------------|-----------|--------------|----------------|
| 1 | **`sv → sv`** (in-process) | Free | Direct Python call | Live CPython objects (by ref) | -- (plain `import`) |
| 2 | **`sv → sv`** (microservice) | Marshalled | HTTP `POST` between deployments | JSON (`_to_wire`/`_from_wire`) | `PyastGenPass` (`sv import` stub) + `jac-scale` |
| 3 | **`cl → cl`** | Free | Direct JS call | JS values (by ref) | -- (`cl import`) |
| 4 | **`na → na`** | Free | Linker symbol reference | Native values / pointers | `NativeCompilePass` relocation |
| 5 | **`cl → sv`** | Marshalled | HTTP `POST /walker/*` or `/function/*` | JSON envelope | `EsastGenPass` (`__jacSpawn`/`__jacCallFunction`) + `jac-scale` |
| 6 | **`sv → cl`** | Marshalled (one-shot) | Static bundle + bootstrap JSON (CSR) | The compiled JS bundle + init payload | `PyastGenPass` static route + Vite/Bun bundler |
| 7 | **`sv → na`** | Marshalled | `ctypes.CFUNCTYPE` over the JIT address (or AOT `.so`) | C-ABI scalars; Jac objects as zero-copy views | `PyastGenPass` ctypes stub + `NaIRGenPass` C-ABI export |
| 8 | **`na → sv`** | Marshalled | Python callback registered as a JIT symbol | C-ABI scalars | `interop_bridge` (`llvm.add_symbol`) |
| 9 | **`cl → na`** | Marshalled | JS calls exported wasm functions | wasm scalars / linear memory | `wasm_build` + `WasmLinker` exports |
| 10 | **`na → cl`** | Marshalled | wasm imports the host `env` object | wasm scalars; host-provided externs | `WasmLinker` import table + cl host shim |
| 11 | **`sv/na ↔ py`** | Free | Literal Python import / meta-path finder | Live CPython objects | `PyastGenPass` (`import`→`ast.Import`) + `meta_importer` |
| 12 | **`na ↔ C`** | Marshalled (ABI) | System V AMD64 / AAPCS calling convention | C scalars & structs (by value or pointer) | `NaIRGenPass` clib marshaller |
| 13 | **`na → C host`** | Marshalled (ABI) | `--shared` C-ABI export | Scalars by value; Jac objects as opaque handles | `nacompile` `_inject_shared_init` + platform linkers |

The rest of the document is one section per group of rows.

---

## Free boundaries (rows 1, 3, 4, 11)

A free boundary is "interop" only in the bookkeeping sense -- there is no
wire format, no copy, and no generated glue. Two declarations in the *same*
codespace simply reference each other directly:

- **`sv → sv`** -- Jac server code is CPython bytecode. A `def` calling
  another `def` is an ordinary Python call; an `obj` handed to another
  function is the *same* object, not a copy. Plain (untagged) Jac `import`
  statements lower verbatim to Python `import` nodes (`exit_import` in
  [`pyast_gen_pass.impl.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/passes/impl/pyast_gen_pass.impl.jac)),
  so resolution is the standard CPython import machinery.
- **`cl → cl`** -- Client code becomes one JavaScript module graph; a `cl`
  function calling another is a direct JS call, bundled together by Vite.
- **`na → na`** -- Two native modules link at the IR/object level. An import
  is a direct symbol reference resolved by the in-tree linker
  (`_compile_and_link_native_imports` in `NativeCompilePass`). The linker
  rejects duplicate *owned* symbols with `E5026`.
- **`sv ↔ py`** -- Because `sv` *is* the Python target, server code and
  imported Python share one interpreter, one `sys.modules`, and one object
  model. This is covered in full under [Python interop](#python-interop-row-11)
  below.

> The single most important consequence: **values only need a wire format
> when they cross a marshalled boundary.** Inside one codespace (or between
> `sv` and Python) you pass live objects around for free.

---

## `cl → sv`: the full-stack RPC (row 5)

This is the boundary that makes a Jac app full-stack: client-side
JavaScript calling server-side walkers and functions over HTTP.

### Declaring the contract

A `.cl.jac` component imports its server contract with `sv import`:

```jac
sv import from endpoints { Message, PostMessage, ListMessages }
```

Inside a client file, the `sv` prefix is the one carve-out that survives
client coercion: `_coerce_client_module` passes `skip_token=Tok.KW_SERVER`,
so an `sv`-tagged statement keeps `CodeContext.SERVER` instead of being
re-stamped `CLIENT`. The server side defines these as **public walkers**
(`walker:pub`) and **boundary types** (`node`/`obj`) with typed
`reports`/return signatures, e.g.:

```jac
walker:pub PostMessage {
    has author: str,
        text: str,
        reports: list[Message] = [];   # typed result the client sees

    can post with Root entry {
        report here ++> Message(author=self.author, text=self.text);
    }
}
```

`BoundaryAnalysisPass` sees the `KW_SERVER` import, re-reads
`endpoints.sv.jac`, and records each walker's fields and each function's
signature into an `InteropBinding`. The client gets full type information
by reading the server's source directly -- there is no shared type-checker
round-trip.

### Lowering the call site

`EsastGenPass` rewrites client call sites into runtime stubs:

| Client source | Lowered to | Runtime helper |
|---------------|------------|----------------|
| `root spawn PostMessage(...)` | `await __jacSpawn("PostMessage", <target>, {fields})` | `__doWalkerFetch` |
| `someServerFn(...)` (a `def:pub`) | `await __jacCallFunction("someServerFn", {args})` | `__doFuncFetch` |

The function path is gated in `_try_lower_server_rpc_call`: the callee must
be a non-client `def` whose access tag is `KW_PUB`. Typed arguments are
wrapped with `__to_wire()` on the way out, and the return is rehydrated on
the way back -- a `list[Message]` becomes
`(await call).map(x => Message.__from_wire(x))`, a bare `Message` becomes
`Message.__from_wire(await call)`.

### The HTTP call

The runtime helpers live in
`runtimelib/impl/client_runtime.impl.jac`. The base URL comes from a Vite
build-time define (`globalThis.__JAC_API_BASE_URL__`, defaulting to
same-origin). A walker call resolves to:

```text
POST {base}/walker/{WalkerName}            # root-targeted
POST {base}/walker/{WalkerName}/{nodeId}   # node-targeted
POST {base}/function/{funcName}            # public function
```

with a `Bearer` token from `localStorage["jac_token"]` and a
`JSON.stringify`d body. A `401` drops the token and reloads. Calls route
through `__cachedEndpointCall`, an LRU+TTL cache driven by compiler-emitted
`__jacEndpointEffects__` metadata: endpoints tagged *reader* are cached and
deduped, *writer* endpoints fetch then invalidate overlapping readers
(auth walkers always bypass the cache).

### The server endpoint

The HTTP server is **not** in the compiler -- it is the `jac-scale` plugin
(`jac-scale/jac_scale/jserver/`, a FastAPI/uvicorn binding written in Jac).
`jac start` brings it up. For every public walker it registers two routes
(`register_walkers_endpoints`):

```text
POST /walker/<name>/{nd}   # node-targeted
POST /walker/<name>        # root-targeted
```

The callback runs `execution_manager.spawn_walker(...)` (or
`execute_function(...)`) inside the caller's graph context. A `restspec` on
the walker can override the path/method; `/webhook/<name>` (HMAC-signed) and
`/ws/<name>` (WebSocket) are alternative protocols on the same machinery.

---

## `sv → cl`: client delivery (row 6)

There is **no runtime call from server to client.** The client is
client-side-rendered (CSR): the server compiles, bundles, and serves the
client JavaScript plus a one-shot bootstrap payload; the browser mounts
React itself. There is no SSR/hydration path -- the runtime contains
`createRoot(...).render(...)` but never `renderToString`/`hydrateRoot`.

### JSX lowering

JSX is context-neutral AST. `EsJsxProcessor` lowers each element to a
`__jacJsx(tag, props, children)` call -- a thin wrapper over
`React.createElement` (capitalised tag → component identifier, lowercase →
intrinsic HTML string). Reactivity maps onto React: a `has` becomes
`useState`, `can ... with entry` becomes `useEffect`.

### Bundle and serve

The pipeline lives in `runtimelib/client/`:

1. **Jac → JS** -- `ViteCompiler.compile` runs the normal compile and reads
   each module's `mod.gen.js`, plus compiles the client runtime.
2. **Entry** -- writes an `_entry.js` with the `createRoot(...).render(...)`
   mount.
3. **Bundle** -- `ViteBundler.build` resolves Bun (pinned, auto-downloaded),
   runs `bun install` then `bun x vite build` with `@vitejs/plugin-react`,
   producing a content-hashed `client.<hash>.js` (+ `styles.css`).
4. **Serve** -- the Python server serves the JS from memory at
   `GET /static/client.js`; other assets from `.jac/client/dist/`.

The HTML shell embeds a bootstrap `<script type="application/json">`
payload (module name, render function, args, client globals, `argOrder`,
and the `endpointEffects` map that powers the RPC cache) plus a
`<script type="module" src="/static/client.js?hash=...">`. The `?hash`
busts the cache on every bundle change. The browser reads the payload and
mounts React; **the server never renders DOM.**

---

## `sv ↔ na`: the Python ⇄ native JIT bridge (rows 7, 8)

When one program mixes server (`sv`/default) and native (`na {}`) code, the
compiler auto-generates a **bidirectional ctypes bridge** -- there is no
manual FFI. The two directions are derived from the `InteropManifest`:
`native_exports` (native function, Python caller) and `native_imports`
(Python function, native caller).

### `sv → na` -- Python calls native

`PyastGenPass._gen_native_interop_stubs` emits a Python wrapper per native
export. At call time it resolves the JIT address and builds a typed ctypes
trampoline:

```python
_addr = __jac_native_engine__.get_function_address('add')
_fn   = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64, ctypes.c_int64)(_addr)
return _fn(a, b)
```

### `na → sv` -- native calls Python

`interop_bridge.register_py_callbacks` wraps each referenced Python function
in a `ctypes.CFUNCTYPE`, keeps the reference alive, and calls
`llvm.add_symbol(name, cb_addr)` so MCJIT resolves the *native* call
straight into CPython. The scalar type map (`JAC_TO_CTYPES`) is
`int→c_int64`, `float→c_double`, `bool→c_bool`, `str→c_char_p`.

### The engine and the in-process model

`NativeCompilePass.transform` parses and verifies the IR, **registers the
Python callbacks before creating the engine**, links na↔na imports at the
IR level, then `llvm.create_mcjit_compiler(...)` and stores the engine on
`module.gen.native_engine`. This is the key fact: in the mixed-file case
the native code is **JIT-compiled into the same process** as the Python
runtime, so the "bridge" is two ctypes hops within one address space -- not
a separate shared object loaded across a process boundary.

### Crossing whole Jac values

For full `.na.jac` modules, `native_marshal.jac`'s `install_native_wrappers`
replaces each exported name with a wrapper, and `marshal_value` crosses Jac
`obj`/`list` values as **zero-copy views**: `NativeStructView` /
`NativeListView` read fields directly from native memory via ctypes
`from_address()` (no deep copy); `i8*` decodes to `str` lazily; enum
ordinals map back to Python enum members. This is why nearly every Jac type
can cross -- the exception being Python-style monkey-patched classes.

### AOT alternative

`jac run --autonative` JITs `jac_entry` directly when a module is
`native_compat` (and silently falls back to the Python path otherwise). The
*ahead-of-time* counterpart is the **`na → C host`** shared-library export
path (below), where the native side is packaged as a real `.so` and a host (Python via `ctypes`, or C) loads
it across the process boundary.

---

## `na ↔ C`: foreign function interface (row 12)

Native Jac calls C the way C calls C -- by implementing the platform calling
convention exactly. This is the most ABI-intensive boundary in the system.

### Declaring foreign code

<!-- jac-skip -->
```jac
import from "libm.so"  { def sqrt(x: float) -> float; }   # literal path, verbatim
import from raylib     { def InitWindow(w: int, h: int, title: str); obj Color { has r: int; ... } }
import from .mylib     { ... }                              # relative
```

The parser sets `is_clib_import` when the from-path is a string literal or
the block opens with a declaration keyword, populates `Import.clib_decls`,
and stamps `CodeContext.NATIVE`. A logical name (`raylib`) is mapped to
`libraylib.so` / `.dylib` / `raylib.dll` per target triple, and the runpath
is emitted as ELF `DT_RUNPATH=$ORIGIN` (or Mach-O `@loader_path`). A `str`
parameter lowers to `i8*`. A clib declaration with a *body* is an error
(`E5060`).

### The three-layer ABI implementation

| Layer | File | Responsibility |
|-------|------|----------------|
| **Declaration model** | `compiler/targets/foreign.jac` | What the user declared: scalar sizes (`FOREIGN_SCALARS`), C struct layout (`foreign_struct_layout` -- byte offsets, alignment, tail padding, nested-by-value flattening) |
| **psABI classifier** | `compiler/targets/abi.jac` | Pure calling-convention logic: `classify_struct` dispatches on the triple -- `aarch64`/`arm64` → AAPCS, else System V AMD64 |
| **Backend marshaller** | `na_ir_gen_pass.impl/clib_abi.impl.jac` | Emits the actual call: applies the plan, builds the parallel `.cabi` LLVM type, copies between Jac and C layouts |

### How structs cross

The classifier returns a *plan* that the marshaller applies at the call
site. Whether a struct travels by pointer or by value differs for
*Jac-native* structs vs *foreign C* structs (see the contrast note below).

- **System V AMD64** (`classify_struct_sysv`): a struct > 16 bytes is
  **MEMORY** class -- passed via a `byval` pointer (the backend copies),
  returned via an `sret` hidden pointer. A struct ≤ 16 bytes is split into
  *eightbytes*, each classed INTEGER or SSE and lowered to a register
  **coerce** piece (`iN`, `float`, `double`, or `<2 x float>`). So a small
  C struct is passed *by value, in registers*, not by pointer.
- **AAPCS (arm64)**: HFAs (≤ 4 same-type floats) ride a `[N x float/double]`
  coerce; ≤ 16-byte aggregates ride `i64`/`[2 x i64]`; larger aggregates
  pass indirectly via a **caller-made copy** (a plain pointer, not `byval`).

The marshaller marks `byval`/`sret` on **both** the function declaration and
the call instruction -- omit either and LLVM passes the pointer in a register
instead of copying the aggregate, silently violating the ABI.

> **Contrast with Jac-native structs.** A user-defined Jac `obj` is a
> reference-counted heap allocation and lowers to *pointer-to-struct*
> everywhere, so it is always passed **by pointer**. The by-value register
> splitting above applies **only** to foreign C structs crossing the FFI,
> because the C ABI demands it.

### C → Jac callbacks (vtables)

For C APIs whose structs hold function-pointer fields (CEF, libuv), a Jac
`def` stored into such a slot is wrapped in a **C-ABI trampoline**
(`_emit_clib_c_trampoline`) that coerces each argument to the Jac parameter
type (sign-extend/truncate per C signedness), calls the Jac function, and
coerces the result back. Trampolines are cached as `{fn}.__clibcb.{n}`.
Vtable instances are `calloc`'d as flat C memory with **no RC header** --
the C runtime owns their lifetime.

---

## `na → C host`: shared libraries (row 13)

The inverse of FFI-in. `jac nacompile mathlib.na.jac --shared` packages a
native module as a C-ABI `.so` / `.dylib` / `.dll` that any host (a C
program, or Python via `ctypes`) can load across a process/module boundary.

- **Export surface** -- only `:pub` symbols. `def:pub` / `glob:pub` names are
  recorded into `gen._exported_symbols` (re-exported transitively from
  imported native modules). Methods are *not* exported (class-qualified
  symbol) -- wrap them in a `:pub` free function.
- **Initialisation** -- `_inject_shared_init` emits `@__jac_shared_init`,
  hooked via ELF `DT_INIT_ARRAY` / Mach-O `__mod_init_func` / PE `DllMain`,
  so global initialisers run on load with no `jac_init()` call required.
- **Object lifetime** -- Jac objects cross the ABI as **opaque `void*`
  handles**; the host must not dereference them. `@jac_retain` / `@jac_release`
  (public wrappers over the RC primitives) let the host manage their
  lifetime.
- **Scalars** pass by value (`int → int64`, `float → double`). `--shared`
  forces PIC and skips `internalize` so the public symbols survive.

---

## `na ↔ cl`: WebAssembly (rows 9, 10)

Native code reaches the *client* by compiling to wasm.
`jac nacompile --target wasm32` (and the client bundler's `_emit_na_wasm`,
which serves `/static/<stem>.wasm`) both route through
`wasm_build.compile_to_wasm`: it sets the `wasm32-unknown-unknown` triple,
compiles AOT, runs `opt2` **without** `internalize` (so defined functions
stay exported), and links with the pure-Jac `WasmLinker` (no
wasm-ld/emscripten).

The interop model is the standard wasm import/export contract:

- **`cl → na`** (exports) -- `WasmLinker` exports `memory`, the
  `__stack_pointer`/`__heap_base` globals, and **every defined function**
  (or an explicit `export_funcs` list). JS calls these directly after
  `WebAssembly.instantiate`.
- **`na → cl`** (imports) -- undefined externs (raylib, `malloc`/`free`/
  `memcpy`, compiler-rt helpers like `__multi3`) remain wasm **imports** from
  module `"env"`. The JS host satisfies them by providing an
  `importObject.env` at instantiate time; the client shim supplies the
  externs. So native code calls back into JS through these imported `env`
  functions.

---

## `sv → sv` microservice split (row 2)

By default an `sv import` between two server modules is a free, in-process
Python import. Prefixing it with `sv` **explicitly** turns it into an HTTP
boundary even between two server deployments:

```jac
sv import from billing { ChargeCard }   # billing may be a different process
```

`exit_import` detects the literal `KW_SERVER` source token (not
`code_context`, which is `SERVER` for everything by default) and calls
`_generate_sv_to_sv_stubs`, replacing the import with generated Python:

- functions → a stub whose body is
  `__jac_sv_client.call('<module>', '<func>', {args})`, with boundary types
  serialised via `_to_wire()` / `<Type>._from_wire(...)`;
- walkers → `__jac_sv_client.spawn_walker(...)`.

At runtime the provider URL comes from `JAC_SV_<MODULE>_URL`, else an
auto-started loopback sibling. This is the only place a `.jac` → Python
lowering converts an import into an RPC; it is consumed by `jac-scale`.

---

## Python interop (row 11)

`sv` *is* the Python codegen target, so Python interop is the same
execution substrate -- free and unmarshalled -- in both directions.

### Jac importing Python

A plain Jac `import` lowers verbatim to a Python import node:

| Jac | Python AST |
|-----|------------|
| `import math;` | `Import(names=[alias('math')])` |
| `import from os.path { join }` | `ImportFrom(module='os.path', names=[alias('join')], level=0)` |
| `include foo;` | `ImportFrom(..., names=[alias('*')])` |
| `import type X;` | wrapped in `if TYPE_CHECKING:` |

Because these are real Python imports, `pandas`/`numpy`/`sklearn` "just
work." Untyped Python return values arrive in Jac as `any`. Inline Python
via `::py::` blocks is parsed into a `PyInlineCode` node and spliced
verbatim into the Python AST (server backend only).

### Python importing Jac

A lazily-installed meta-path finder makes `.jac` modules first-class to
CPython. The `jac` binary's launcher runs `import _jac_finder;
_jac_finder.install()` at interpreter startup (see `launcher/launcher.zig`
`BOOT_SRC`); on the first `.jac` import the lazy finder bootstraps jaclang and
installs `JacMetaImporter`
([`meta_importer.py`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/meta_importer.py)).
Its `find_spec` probes for `__init__.jac` / `<name>.jac` / `<name>.sv.jac`,
and `exec_module` runs `exec(codeobj, module.__dict__)` -- so a compiled Jac
module becomes an ordinary Python module object in `sys.modules`, with Jac
archetypes appearing as plain Python classes (`obj → class X(Obj)`). Pure
Python callers reach the runtime via
`from jaclang.lib import Node, Walker, connect, spawn, root`.

`.py` / `.pyi` files inside a Jac program take the reverse bridge: they are
loaded through `PyastBuildPass`, which builds a UniTree `Module` from a
Python AST so they participate in the same compilation hub.

---

## The marshalling format

Everything crossing a marshalled boundary is **JSON** (for `cl↔sv` and the
`sv→sv` split) or a **C-ABI value** (for `na`). The wire serialiser is
`runtimelib/impl/serializer.impl.jac`.

### JSON wire format (`cl↔sv`, `sv→sv`)

- **Request** -- the client sends `JSON.stringify(args)`; typed boundary
  args are pre-wrapped with `__to_wire()`. On the server,
  `_deserialize_wire_args` rehydrates any dict/list element carrying a
  `__type__` tag back into a Jac object via `Serializer.deserialize` before
  the walker/function runs.
- **Response** -- after execution, `_finalize_call_response` serialises the
  result and `reports` with `api_mode=True`. In `api_mode`, nodes/edges
  carry graph metadata (`_jac_type`, `_jac_id`, `_jac_archetype`), and
  custom objects are tagged with `__type__` -- the exact shape the client's
  `__from_wire` and the server's `_deserialize_wire_args` read back.
- **Envelope** -- the outer HTTP body is a `TransportResponse`:

  ```json
  { "ok": true, "type": "...", "data": { "result": ..., "reports": [...] },
    "error": null, "meta": { } }
  ```

  The client unwraps `payload.data` (walkers) or `payload.data.result`
  (functions), then runs typed values through `__from_wire`. Errors come
  back `{ "ok": false, "error": { "code", "message", "details" } }`.

### C-ABI wire format (`na`)

Scalars use the `JAC_TO_CTYPES` map (`int→c_int64`, `float→c_double`,
`bool→c_bool`, `str→c_char_p`). Whole Jac values cross the JIT bridge as
**zero-copy `NativeStructView`/`NativeListView`** over native memory.
Foreign C structs cross by the platform ABI (`byval`/`sret`/register
coerce) as described above.

### What is allowed to cross

The **primitive contract** guarantees that `int`, `str`, `list[str]`, etc.
mean the same thing on both sides. Non-primitive types must be **reachable
in both codespaces** -- typically a plain `obj`/`node` archetype that travels
as JSON with `__type__`/`_jac_type` metadata (`cl↔sv`) or as a zero-copy
view (`na`). Live runtime resources (open file handles, sockets) do not
serialise and cannot cross.

For `na`, an additional hard limit applies: the **native capability
boundary**. `native_capability_violations` (the single authority behind
`E5090`, run identically at `jac check` and `jac nacompile`) rejects
constructs the native backend cannot lower -- non-allowlisted imports
(allowlist: `sys`, `math`, `time`, `os`, `random`), structural match
patterns, generators (`yield`), inline Python (`::py::`), `by llm()`, and a
handful of edge-traversal forms. Anything `E5090` rejects can never reach,
let alone cross, the native boundary. See
[Native Compilation](../reference/language/native-pathway.md) for the full
list.

---

## Desktop apps: stitching the boundaries together

A Jac **desktop app** is the most integrated use of the matrix: it bundles
the `cl` UI, a native (`na`) host binary, the OS's own webview, and an
embedded CPython into a single shippable artefact. The desktop target is
built into `jaclang` core (`jac/jaclang/runtimelib/client/targets/desktop/`).

> **Status note.** Older release notes mention a "PyTauri shell +
> PyInstaller sidecar" and a `jac desktop` CLI -- those are **stale**. The
> shipping architecture is a native host binary + the OS webview, and there
> is no dedicated `jac desktop` command. Wiring the `sv` walkers onto the
> *embedded* interpreter is still in progress (issue #6436); today the UI
> talks to a backend `sv` server reached via `api_base`, while the embedded
> CPython runs a stdlib loopback broker that serves the bundle and brokers
> SSO.

### Developer workflow

Configuration is declarative in `jac.toml`:

```toml
[plugins.desktop]
name = "my-app"
[plugins.desktop.window]
title  = "My App"
width  = 1000
height = 700
```

```bash
jac build --client desktop   # -> .jac/client/desktop/<app> (binary + dist/ + libwebview.so)
jac start --client desktop   # build if needed, then launch the native window
(cd .jac/client/desktop && ./my-app)   # or run the binary directly
```

`--client desktop` resolves through the client framework's target registry
(`get_target_type("desktop") → TargetType.DESKTOP`), which lazy-loads the
core-registered `NativeDesktopTarget`. There is no separate CLI verb -- the
core `build`/`start` commands delegate to the target.

### How the targets combine

| Layer | Codespace / tech | Role |
|-------|------------------|------|
| UI | `cl` (Vite/React bundle) | `NativeDesktopTarget` subclasses `WebTarget`; reuses the standard `.jac/client/dist/` bundle |
| Host binary | `na` (LLVM, pure-Jac linker) | A generated `host.na.jac`, compiled by `jac nacompile`; records `libwebview.so` as `DT_NEEDED` with an `$ORIGIN` runpath |
| Window | C FFI → `libwebview` | OS-native webview: WebKitGTK (Linux), WKWebView (macOS), WebView2 (Windows) |
| Local runtime | C FFI → `libpython` | Embedded CPython runs a stdlib loopback HTTP server (the OAuth/bundle broker) |
| Backend | `sv` over HTTP | Reached via `api_base` (currently remote; in-process embedding is the goal of #6436) |

The generated host wires it all together (paraphrasing
`native_desktop_target.impl.jac`):

<!-- jac-skip -->
```jac
import from webview { Webview, new_webview }
import from "libpython3.x.so" { Py_Initialize, PyRun_SimpleString, ... }

with entry {
    Py_Initialize();
    PyRun_SimpleString(SERVE_PY);     # loopback http.server (broker) in a daemon thread
    url = f"http://127.0.0.1:{port}/";
    wv  = new_webview(False);
    wv.title(...); wv.size(...); wv.on_load(BOOTSTRAP_JS);
    wv.navigate(url);
    ts = PyEval_SaveThread(); wv.run(); PyEval_RestoreThread(ts);   # GIL released while the window blocks
    Py_Finalize();
}
```

So a desktop app exercises, in one process, the chain:

```text
cl bundle  ──(served by)──▶  embedded CPython (loopback broker)
   ▲                                   │
   │ rendered in                       │ na host binary
OS webview  ◀──(C FFI: libwebview)── na  ──(C FFI: libpython)── CPython
   │
   └──(HTTP: cl → sv RPC)──▶  sv backend (api_base)
```

The loopback port is deterministic -- `49152 + sha1(app_name) % 16000` -- so
the webview's per-origin `localStorage` (login/session) survives restarts.

### Boundary chain summary

Reading the diagram as interop rows: a desktop app combines
**`sv → cl`** (bundle delivery, served locally), **`na ↔ C`** (the host
binding `libwebview` and `libpython`), **`na → C host`** inverted (the host
*embeds* CPython rather than exporting to it), and **`cl → sv`** (the UI's
RPC to the backend). It is the matrix in miniature.

---

## Where to look in the source

| Concern | Files |
|---------|-------|
| Boundary discovery | `jac0core/passes/impl/boundary_analysis_pass.impl.jac`; `InteropAnalysisPass`; [`codeinfo.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/codeinfo.jac) (`InteropBinding`, `InteropManifest`) |
| Context split / coercion | [`compiler.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/compiler.jac) (`_coerce_module`); `constant.jac` (`CodeContext`) |
| `cl → sv` | `compiler/passes/ecmascript/impl/esast_gen_pass.impl.jac` (`__jacSpawn`/`__jacCallFunction`); `runtimelib/impl/client_runtime.impl.jac`; `jac-scale/jac_scale/impl/serve.endpoints.impl.jac` |
| `sv → cl` | `runtimelib/client/impl/{compiler,vite_bundler}.impl.jac`; `runtimelib/impl/server.impl.jac`; `passes/ast_gen/impl/jsx_processor.impl.jac` |
| `sv ↔ na` | `jac0core/{interop_bridge,native_marshal}.jac`; `passes/impl/pyast_gen_pass.impl.jac` (`_gen_native_interop_stubs`, `_generate_sv_to_sv_stubs`); `passes/native/impl/na_compile_pass.impl.jac` |
| `na ↔ C` | `compiler/targets/{foreign,abi}.jac`; `passes/native/na_ir_gen_pass.impl/{clib_abi,clib_vtable}.impl.jac` |
| `na → C host` | `cli/commands/impl/nacompile.impl.jac` (`_inject_shared_init`); `passes/native/impl/{elf,macho,pe}_linker.impl.jac` |
| `na ↔ cl` (wasm) | `passes/native/{wasm_build,wasm_linker}.jac`; `runtimelib/client/impl/compiler.impl.jac` |
| Python interop | [`meta_importer.py`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/meta_importer.py); `_jac_finder.py` (launcher `BOOT_SRC`); `passes/impl/pyast_gen_pass.impl.jac` (`exit_import`, `exit_py_inline_code`) |
| Marshalling | `runtimelib/impl/{serializer,server,transport}.impl.jac` |
| Capability boundary | `compiler/passes/main/capability_check_pass.jac`; [`diagnostics.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/jac0core/diagnostics.jac) (`E5090`) |
| Desktop | `runtimelib/client/targets/desktop/native_desktop_target.jac` (+ impl); `runtimelib/client/targets/desktop/native/webview/webview.na.jac`; `runtimelib/client/targets/registry.jac` |

---

## See also

- [Compiler Architecture: Three Codespaces](compiler_architecture.md) -- the codespace model and pipeline.
- [Jac Client Import Patterns](jac_import_patterns.md) -- the `cl import` surface.
- [Native Compilation](../reference/language/native-pathway.md) -- the `na` pathway and the capability roadmap.
- [Python Integration](../reference/language/python-integration.md) -- the five Jac/Python adoption patterns.
