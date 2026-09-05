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

The compiler decides which is which automatically. One analysis pass does
the discovery:

- **`BoundaryAnalysisPass`** detects a cross-runtime import (a
  server-module import in client-placed code -- whether that placement is
  inferred or comes from a `.jac` variant file -- a `clib` import in
  native code, etc.) and re-reads the *provider* module's AST to extract
  the public surface -- walker `has`-fields, `def` signatures, struct
  layouts -- into an `InteropBinding`. On an import, service-boundary
  status is a config fact (the target module is in
  `[scale.microservices.routes]` or pinned `"server"` in
  `[placement.pins]`); the import's own `code_context` is its
  placement, which determines the caller side of the binding. The same pass
  walks call sites, records the caller's and callee's `CodeContext` plus
  the boundary types, and accumulates every binding into an
  `InteropManifest`.

The results land in the schemas in
[`compiler/frontend/codeinfo.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/frontend/codeinfo.jac).
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
| 2 | **`sv → sv`** (microservice) | Marshalled | HTTP `POST` between deployments | JSON (`_to_wire`/`_from_wire`) | `JcirGenPass` (service RPC stub for routes-table imports) + `jaclang.scale` |
| 3 | **`cl → cl`** | Free | Direct JS call | JS values (by ref) | -- (plain client-side `import`) |
| 4 | **`na → na`** | Free | Linker symbol reference | Native values / pointers | `NativeCompilePass` relocation |
| 5 | **`cl → sv`** | Marshalled | HTTP `POST /walker/*` or `/function/*` | JSON envelope | `EsastGenPass` (`__jacSpawn`/`__jacCallFunction`) + `jaclang.scale` |
| 6 | **`sv → cl`** | Marshalled (one-shot) | Static bundle + bootstrap JSON (CSR) | The compiled JS bundle + init payload | `JcirGenPass` static route + Vite/Bun bundler |
| 7 | **`sv → na`** | Marshalled | `ctypes.CFUNCTYPE` over the JIT address (or AOT `.so`) | C-ABI scalars; Jac objects as zero-copy views | `JcirGenPass` ctypes stub + `NaIRGenPass` C-ABI export |
| 8 | **`na → sv`** | Marshalled | Python callback registered as a JIT symbol | C-ABI scalars | `interop_bridge` (`llvm.add_symbol`) |
| 9 | **`cl → na`** | Marshalled | JS calls exported wasm functions | wasm scalars / linear memory | `wasm_build` + `WasmLinker` exports |
| 10 | **`na → cl`** | Marshalled | wasm imports the host `env` object | wasm scalars; host-provided externs | `WasmLinker` import table + cl host shim |
| 11 | **`sv/na ↔ py`** | Free | Literal Python import / meta-path finder | Live CPython objects | `JcirGenPass` (`import`→`ast.Import`) + `meta_importer` |
| 12 | **`na ↔ C`** | Marshalled (ABI) | System V AMD64 / AAPCS calling convention | C scalars & structs (by value or pointer) | `NaIRGenPass` clib marshaller |
| 13 | **`na → C host`** | Marshalled (ABI) | `--shared` C-ABI export | Scalars by value; Jac objects as opaque handles | the link plan's glue object (`backends/native/link_glue.jac`) + platform linkers |

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
  [`jcir_gen_pass.impl.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/backends/py/impl/jcir_gen_pass.impl.jac)),
  so resolution is the standard CPython import machinery.
- **`cl → cl`** -- Client code becomes one JavaScript module graph; a `cl`
  function calling another is a direct JS call, bundled together by Vite.
- **`na → na`** -- Two native modules are two native units. An import is a
  direct symbol reference to the defining unit's module-qualified symbol
  (recorded in its `SEC_NIFACE`), and the link plan
  (`backends/native/link_plan.jac`) brings the unit's object into the
  artifact. Two units defining one Jac name never collide; `E5026` remains
  for two `:pub` exports of one name in one link.
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

A client component imports its server contract with a plain import:

```jac
import from endpoints { Message, PostMessage, ListMessages }
```

The placement solver leaves the endpoints module's API surface
server-placed (`def:pub` endpoints and walkers never relocate), so the
client-consumed import is recognized as a boundary import rather than a
relocation. The server side defines these as **public walkers**
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

`BoundaryAnalysisPass` sees the boundary import, re-reads
`endpoints.jac`, and records each walker's fields and each function's
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
`client/impl/client_runtime.impl.jac`. The base URL comes from a Vite
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

The HTTP server is **not** in the compiler -- it is the built-in `scale` subsystem
(`jac/jaclang/scale/server/`, built on the Jac-native asyncio HTTP stack in
`jaclang/server/serving/`).
`jac run` brings it up. For every public walker it registers two routes
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

The pipeline lives in `client/`:

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

When one program mixes server (the default) and native-placed code, the
compiler auto-generates a **bidirectional ctypes bridge** -- there is no
manual FFI. The two directions are derived from the `InteropManifest`:
`native_exports` (native function, Python caller) and `native_imports`
(Python function, native caller).

### `sv → na` -- Python calls native

`JcirGenPass._gen_native_interop_stubs` emits a Python wrapper per native
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

Whole-value crossings are **one-way and total**: the native side rebuilds
the value as real CPython objects before it returns, and nothing native
outlives the call. There is no view layer -- the earlier zero-copy
`NativeStructView`/`NativeListView` machinery was deleted with #8139 Step 2
once measurement showed per-access view reads losing to outright
materialization for every real consumer.

No whole-value crossing ships today. The worked example used to be the
compiler's own sealed parser, whose generated materializer root returned
fully Python-owned trees, envelopes and all; it went with the native seal
in #8735 (#8732). What crosses now is narrower: scalars, through the ctypes
trampolines above, or -- on the `na → C host` path (row 13 below) -- opaque
`void*` handles the host reference-counts with `@jac_retain` /
`@jac_release` and must never dereference. The rule above is the contract
the next crossing has to meet; the entries that meet it are its own to write.

### AOT alternative

`jac run` JITs `jac_entry` directly when a markerless module infers
native, which is the default codespace preference (demoting gracefully
to the Python path when it cannot lower). The
*ahead-of-time* counterpart is the **`na → C host`** native-lib export
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
| **Declaration model** | `compiler/backends/native/foreign.jac` | What the user declared: scalar sizes (`FOREIGN_SCALARS`), C struct layout (`foreign_struct_layout` -- byte offsets, alignment, tail padding, nested-by-value flattening) |
| **psABI classifier** | `compiler/backends/native/abi.jac` | Pure calling-convention logic: `classify_struct` dispatches on the triple -- `aarch64`/`arm64` → AAPCS, else System V AMD64 |
| **Backend marshaller** | `na_ir_gen/clib_abi.impl.jac` | Emits the actual call: applies the plan, builds the parallel `.cabi` LLVM type, copies between Jac and C layouts |

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

The inverse of FFI-in. `jac nacompile mathlib.jac --shared` packages a
native module as a C-ABI `.so` / `.dylib` / `.dll` that any host (a C
program, or Python via `ctypes`) can load across a process/module boundary.

- **Export surface** -- only `:pub` symbols. `def:pub` / `glob:pub` names are
  recorded into `gen._exported_symbols` (re-exported transitively from
  imported native modules). Methods are *not* exported (class-qualified
  symbol) -- wrap them in a `:pub` free function.
- **Initialisation** -- the link plan's glue object defines `@__jac_shared_init`,
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
compiles AOT, honors the project's `[gc]` settings (`default = "none"`
builds headerless and audits the IR for `__rc_*` machinery), runs `opt2`
**without** `internalize` (so defined functions stay exported), and links
with the pure-Jac `WasmLinker` (no wasm-ld/emscripten).

The language-level spelling of the crossing is a plain import of a
native-placed module (inferred from its extern-decl surface, or pinned
`"native"`) from client code:

```jac
import from .arena { init, frame }    # arena.jac places native
```

This is the cl → na twin of the client-to-server RPC bridge. The interop
manifest records the target as NATIVE with a CLIENT caller
(`import_binds_client_native` in `compiler/driver/compiler.jac`), which is the
discovery signal (the client build compiles the target module to
`/static/<stem>.wasm`; the module never has to be imported anywhere else),
and it binds each name to a generated stub: `exit_import` in `EsastGenPass`
emits `const { init, frame } = __na_bind("arena", ["init", "frame"])`, where
`__na_bind` (in `@jac/wasm_host`) lazily instantiates the module on first
call and dispatches to its exports. Calls to the bound names type-check as
async in client code (the same coroutine-wrapping that client calls to
server endpoints get), so `await init()` is the natural call shape. On the
Python side the client-consumed import compiles to **nothing** -- it never
executes the native module under CPython, which is what distinguishes it
from a server-consumed import of the same native module (row 7's ctypes
crossing). A module that declares app FFI
registers its host implementations before the first call with
`set_na_env("<stem>", shim, {"env": {...}})`; an FFI-free module needs no
setup at all.

Underneath, the interop model is the standard wasm import/export contract:

- **`cl → na`** (exports) -- `WasmLinker` exports `memory`, the
  `__stack_pointer`/`__heap_base` globals, and **every defined function**
  (or an explicit `export_funcs` list). JS calls these directly after
  `WebAssembly.instantiate`.
- **`na → cl`** (imports) -- the vendored libc floor is linked *into* the
  module, so what remains as wasm **imports** is the versioned `jac_host1`
  host surface (syscall-ish: `write`, `clock_gettime`, ...) plus the app's
  own extern decls (e.g. raylib) under module `"env"`. The JS host satisfies
  them at instantiate time; native code calls back into JS through these
  imported functions.

---

## `sv → sv` microservice split (row 2)

By default an import between two server modules is a free, in-process
Python import. Listing the provider in `[scale.microservices.routes]` (or
pinning it `"server"` at module level in `[placement.pins]`) turns the same
import into an HTTP boundary even between two server deployments:

```jac
import from billing { ChargeCard }   # billing is in the routes table
```

`exit_import` checks `Import.is_service_import` (routes-table membership /
module-level server pin via `compiler/placement/service_cut.jac` and
`compiler/placement/placement_pins.jac` -- not `code_context`, which is `SERVER` for
everything by default) and calls `_generate_sv_to_sv_stubs`, replacing the
import with generated Python:

- functions → a stub whose body is
  `__jac_sv_client.call('<module>', '<func>', {args})`, with boundary types
  serialised via `_to_wire()` / `<Type>._from_wire(...)`;
- walkers → `__jac_sv_client.spawn_walker(...)`.

At runtime the provider URL comes from `JAC_SV_<MODULE>_URL`, else an
auto-started loopback sibling. This is the only place a `.jac` → Python
lowering converts an import into an RPC; it is consumed by the built-in `scale` subsystem.

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
Its `find_spec` probes for `__init__.jac` / `<name>.jac`,
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
`data/impl/serializer.impl.jac`.

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

  A function declared `@restspec(envelope=False, produces=...)` skips this
  wrapper: its return value is written to the body verbatim under the
  declared content type, for callers that are not Jac clients (a
  `curl | bash` installer, `robots.txt`, a feed). Serialisation still runs,
  so the body is text; error paths keep the envelope. Walkers always keep it,
  having no single value to project. See
  [jac-scale HTTP](../reference/plugins/jac-scale-http.md#raw-response-bodies).

### C-ABI wire format (`na`)

Scalars use the `JAC_TO_CTYPES` map (`int→c_int64`, `float→c_double`,
`bool→c_bool`, `str→c_char_p`). Whole Jac values cross by
**materialization** -- the native side constructs real CPython objects
through libpython externs and hands over ownership (see "Crossing whole
Jac values" above). Foreign C structs cross by the platform ABI
(`byval`/`sret`/register coerce) as described above.

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
built into `jaclang` core (`jac/jaclang/client/targets/desktop/`).

> **Status note.** Older release notes mention a "PyTauri shell +
> PyInstaller sidecar" and a `jac desktop` CLI -- those are **stale**. The
> shipping architecture is a native host binary + the OS webview, and there
> is no dedicated `jac desktop` command. The `sv` walkers and functions run
> **in-process** on the embedded CPython (shipped via #7045): the webview
> binds `__jac_invoke` to `inprocess_dispatch`, so walker/function calls
> never leave the binary. A stdlib loopback broker still serves the bundle
> and brokers SSO/session/logout over `/__jac`. Only per-OS packaging and
> code-signing remain open (issue #6436, phase 5).

### Developer workflow

Configuration is declarative in `jac.toml`:

```toml
[desktop]
name = "my-app"
[desktop.window]
title  = "My App"
width  = 1000
height = 700
```

```bash
jac build --client desktop   # -> .jac/client/desktop/<app> (binary + dist/ + libwebview.so)
jac run --client desktop     # build if needed, then launch the native window
jac run --client desktop --dev     # HMR: Vite on 127.0.0.1 + recompile on .jac saves
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
| Host binary | `na` (LLVM, pure-Jac linker) | A generated `host.jac`, compiled by `jac nacompile`; records `libwebview.so` as `DT_NEEDED` with an `$ORIGIN` runpath |
| Window | C FFI → `libwebview` | OS-native webview: WebKitGTK (Linux), WKWebView (macOS), WebView2 (Windows) |
| Local runtime | C FFI → `libpython` | Embedded CPython runs `inprocess_dispatch` (walker/function invokes) **and** a stdlib loopback HTTP broker (bundle + SSO/session) |
| Backend | `sv` in-process | Walker/function calls route through the embedded runtime via `__jac_invoke`; a remote `api_base` is optional for external backends |

The generated host wires it all together (paraphrasing
`native_desktop_target.impl.jac`):

<!-- jac-skip -->
```jac
import from webview { Webview, new_webview }
import from "libpython3.x.so" { Py_Initialize, PyRun_SimpleString, ... }

with entry {
    Py_Initialize();
    PyRun_SimpleString(BOOT_PY);      # host_boot.boot(): plugins + runtime + loopback broker
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
| Boundary discovery | `compiler/passes/impl/boundary_analysis_pass.impl.jac`; `BoundaryAnalysisPass`; [`codeinfo.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/frontend/codeinfo.jac) (`InteropBinding`, `InteropManifest`) |
| Context split / coercion | [`compiler.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/driver/compiler.jac) (`_coerce_module`); `constant.jac` (`CodeContext`) |
| `cl → sv` | `compiler/backends/es/impl/esast_gen_pass.impl.jac` (`__jacSpawn`/`__jacCallFunction`); `client/impl/client_runtime.impl.jac`; `jac/jaclang/scale/server/impl/serve.endpoints.impl.jac` |
| `sv → cl` | `client/impl/{compiler,vite_bundler}.impl.jac`; `server/impl/server.impl.jac`; `passes/ast_gen/impl/jsx_processor.impl.jac` |
| `sv ↔ na` | `runtime/interop_bridge.jac`; `backends/py/impl/jcir_gen_pass.impl.jac` (`_gen_native_interop_stubs`, `_generate_sv_to_sv_stubs`); `backends/native/impl/na_compile_pass.impl.jac` |
| `na ↔ C` | `compiler/backends/native/{foreign,abi}.jac`; `backends/native/na_ir_gen/{clib_abi,clib_vtable}.impl.jac` |
| `na → C host` | `backends/native/link_plan.jac` + `link_glue.jac`; `backends/native/impl/{elf,macho,pe}_linker.impl.jac` |
| `na ↔ cl` (wasm) | `backends/native/{wasm_build,wasm_linker}.jac`; `client/impl/compiler.impl.jac` |
| Python interop | [`meta_importer.py`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/meta_importer.py); `_jac_finder.py` (launcher `BOOT_SRC`); `backends/py/impl/jcir_gen_pass.impl.jac` (`exit_import`, `exit_py_inline_code`) |
| Marshalling | `data/impl/serializer.impl.jac`; `server/impl/{server,transport}.impl.jac` |
| Capability boundary | `compiler/passes/capability_check_pass.jac`; [`diagnostics.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/frontend/diagnostics.jac) (`E5090`) |
| Desktop | `client/targets/desktop/native_desktop_target.jac` (+ impl); `client/targets/desktop/native/webview/webview.jac`; `client/targets/registry.jac` |

---

## See also

- [Compiler Architecture: Three Codespaces](compiler_architecture.md) -- the codespace model and pipeline.
- [Jac Client Import Patterns](jac_import_patterns.md) -- the client-side import surface.
- [Native Compilation](../reference/language/native-pathway.md) -- the `na` pathway and the capability roadmap.
- [Python Integration](../reference/language/python-integration.md) -- the five Jac/Python adoption patterns.
