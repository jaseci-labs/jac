# js_engine

js_engine is a JavaScript / Node.js-compatible runtime, written from scratch in [Jac Native](https://docs.jaseci.org) and compiled through Jac's LLVM backend into a library the `jac` binary runs. Think of it as a from-the-ground-up answer to [Bun](https://bun.sh/), but built on the Jac toolchain.

It is **not** a wrapper around V8, QuickJS, or any other existing engine. The lexer, parser, bytecode compiler, and virtual machine are all hand-written in `.jac` source files. The only outside code it calls is a handful of C libraries bound through Jac's FFI — libuv, OpenSSL, zlib, zstd, brotli, PCRE2, llhttp, nghttp2 and ICU.

This README is meant to be the one place you go to understand what the project is, how it's built, and how the engine actually executes a script. Treat it as the repo's bible — if something here drifts from the code, fix it here.

## How it ships

js_engine is an accelerator over bun: a release ships bun, and jac runs JavaScript on the engine wherever one is built and current. `zig build js-engine` from `jac/` builds it into `jac/zig-out/js` and installs that directory for every jac:

| File | What it is |
|------|------------|
| `libjs_engine.so` | this project, linked by the in-repo compiler (`jac build --native --lib engine/src/main.jac`, run from here so [jac.toml](jac.toml) applies); OpenSSL, zlib and zstd are linked in statically from the source-built CPython's archives |
| `libjs_native.so` | the foreign code, compiled by Zig from the `build.zig.zon` pins ([native/build_native.zig](native/build_native.zig)): the C shims under `napi/shim` and `native/`, PCRE2, libuv, nghttp2, llhttp, brotli and ICU with its data |
| `builtins.jsbc` | every builtin under `engine/src/builtins/js/`, precompiled by [engine/src/js_compiler.jac](engine/src/js_compiler.jac) |

Every step is cached by the Zig build, and nothing is needed from the system beyond glibc. A current local engine is used when available; otherwise jac uses its installed engine or bun.

The engine is never a separate program. `jac` runs it **as `node`**: the `jac` binary invoked under the name `node` (the engine's `bin/node` link, which jac keeps pointing at itself) loads `libjs_engine.so` and calls `jac_main(argc, argv)`, which runs [main.jac](engine/src/main.jac)'s entry: the bun-compatible package-manager commands first (`install`, `add`, `x`, `run`, ...), then the Node-style script runner. Vite, the `cl` test runner, `jac x` and every npm script run this way, and `process.execPath` names that `node`, so child processes come back to it too. `jac install` and the client build's dependency sync run the package manager the same way, in a child process with the engine's `bin` first on `PATH`, so install scripts that call `node` get the engine.

## Running

```bash
zig build js-engine
jac/zig-out/js/bin/node path/to/script.js
```

Any `node` link to the `jac` binary inside an engine's `bin/` runs that engine. Engine debug flags go before the script: `--ast` (print the parsed AST), `--bc` (print the bytecode), `--norun`, `--debug`, `--gc`/`--nogc` and `--ic`.

## How the engine works

At the highest level, a script flows through four stages — lex, parse, compile, execute:

```
 source text (.js)
     │  parser/lexer.jac        →  tokens
     │  parser/parser.jac       →  AST            (parser/ast.jac)
     │  bytecode/compiler.jac   →  CompiledFunction[]   (bytecode/op.jac)
     ▼  vm/vm.jac               →  runs the bytecode under the event loop
   result
```

Two systems sit alongside that pipeline and touch every stage:

- **The value model** (`runtime/jsvalue.jac`). Every JS value is a single NaN-boxed 64-bit integer, JSC-style. There's no struct and no tagged enum at the value level — integers, doubles, booleans, `null`, `undefined`, and handles to heap cells (strings and objects) are all packed into one 64-bit register. Everything past the parser speaks `JSValue`.
- **Native dispatch** (`builtins/dispatch.jac` and the native registry). This is the bridge that turns a function written in Jac into something callable as a JS function on the global object.

The engine starts in [engine/src/main.jac](engine/src/main.jac), and the little "parse → compile → run" convenience wrapper is `run_script()` in `runtime/global.jac`.

### The lexer — `parser/lexer.jac`

Hand-written, single-pass, and deliberately uses no regex. It turns source text into a flat stream of tokens, each carrying its type, raw text, 1-based line/column, and a `has_newline_before` flag.

A couple of things make it more than a trivial scanner. Whether a `/` begins a regexp or means division can't be settled from the token stream alone, so the *parser* tells the lexer what's coming by calling `set_regexp_mode()` after each token; template literals are stateful in the same way. And the lexer doesn't insert semicolons for ASI — it just records `has_newline_before` and lets the parser decide. Identifiers are ASCII-only for now; full Unicode identifiers aren't implemented yet.

### The AST — `parser/ast.jac`

The AST uses a single "fat node": one `ASTNode` type that carries *every* field any node could ever need. A given node fills in only the fields relevant to its kind and leaves the rest at their defaults. It's a deliberate trade — native compilation wants a fixed, predictable LLVM struct layout, and Jac Native doesn't give us an ergonomic tagged union or inheritance to model node variants, so we spend some memory to get a flat layout. `ASTNodeType` enumerates every node kind.

### The parser — `parser/parser.jac`

Recursive descent with a Pratt (operator-precedence) expression parser on top. It consumes the token stream and builds the AST, and it covers the modern JS surface: classes, destructuring, spread and rest, optional chaining, template literals, generators, async/await, and modules. It's the biggest file on the front end.

### The bytecode compiler — `bytecode/compiler.jac` + `bytecode/op.jac`

This walks the AST and emits bytecode into `CompiledFunction` objects. `op.jac` defines the opcode set and the `disassemble()` routine that backs `--bc`. Every JS function — including the top-level program itself — compiles to its own `CompiledFunction`.

### The virtual machine — `vm/vm.jac`

The interpreter that executes the bytecode over the `JSValue` model. By a wide margin it's the largest file in the repo, because this is where the real work lives: the object model, prototype chains, closures and their captured cells (`vm/cell.jac`, `vm/closure_type.jac`), and dispatch out to the native builtins.

### WebAssembly

The JavaScript `WebAssembly` API is implemented by the Jac-native decoder,
validator and interpreter in `engine/src/wasm/`, with its JS surface in
`engine/src/builtins/js/webassembly.js`. It supports the MVP, sign-extension,
saturating conversions, multi-value, bulk memory and reference types; SIMD,
threads, exceptions, tail calls, GC, memory64 and multi-memory are rejected at
compile time. The engine does not link or load a separate Wasmtime library.

### The event loop — `vm/event_loop.jac`

`el_run(source, script_name, extra_args)` is the true top-level entry point, and it owns the whole lifecycle of a run:

1. Build the `GlobalContext` and initialize the builtins.
2. Spin up the libuv event loop.
3. Run the top-level script synchronously (this is where parse → compile → execute happens).
4. Enter `uv_run(UV_RUN_DEFAULT)` and block until every referenced handle has closed. The script finishing isn't enough to end the process — only live handles like timers, fs operations, and sockets keep the loop alive, exactly as Node and Bun behave.
5. Flush the final callbacks, close the handles, and return.

One subtlety worth knowing: for a normal run, `main.jac` doesn't parse and compile the script itself, because `el_run` already does that internally via `run_script`. The standalone parse/compile calls you see in `main.jac` are only there to feed the `--ast` and `--bc` debug printers.

### Memory — `runtime/gc.jac`, `runtime/gc_mark.jac`

The engine is built under the `rc` memory profile ([jac.toml](jac.toml)): Jac objects are reference counted, and JS heap cells are collected by the engine's own tracing GC.

## Repository layout

```
js_engine/
  jac.toml                 # engine build settings: rc memory, native placement, opt level
  engine/
    src/
      main.jac             # library root: the `node` entry, AST/bytecode debug printers
      js_compiler.jac      # build-time builtins compiler (builtins.jsbc)
      version.jac          # version constants (js_engine, Node compat target, linked libs)
      parser/              # lexer.jac, ast.jac, parser.jac
      bytecode/            # compiler.jac, op.jac, jsbc.jac (the bytecode pack format)
      vm/                  # vm.jac, event_loop.jac, scheduler, timers, cells
      runtime/             # jsvalue, jsstring, jsobject, heap, gc, global, realm, ...
      builtins/            # native builtins (.jac) + JS-side modules (js/*.js)
      ffi/                 # C bindings
      pm/                  # the bun-compatible package manager
      httpcore/ net/ tls/ ws/   # networking stacks
    tests/test262/         # the test262 conformance runner and baselines
  napi/                    # Node-API: the C shim (shim/) and its Jac side (src/)
  native/                  # the tz and ICU C shims, build_native.zig, js_native.ver
  tools/gen_pm_resources.jac   # regenerates pm/resources_gen.jac from pm/help + pm/data
```

## Status

js_engine is pre-alpha — version `0.1.0`. A large chunk of the JS language and the Node.js API works today, but plenty is still stubbed or partial: `eval()`, the `encodeURI`/`decodeURIComponent` family, some `Array` callback paths, full Unicode identifiers, switch fall-through, and computed `delete`, among others. Expect rough edges, and check the source before assuming a given feature is complete.
