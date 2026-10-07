# js_engine

js_engine is a JavaScript / Node.js-compatible runtime, written from scratch in [Jac Native](https://docs.jaseci.org) and compiled down to a single native binary through Jac's LLVM backend. Think of it as a from-the-ground-up answer to [Bun](https://bun.sh/), but built on the Jac toolchain.

It is **not** a wrapper around V8, QuickJS, or any other existing engine. The lexer, parser, bytecode compiler, and virtual machine are all hand-written in `.jac` source files. The only outside code we pull in is a handful of C libraries that we bind through Jac's FFI — libuv, OpenSSL, zlib, PCRE2, llhttp, and nghttp2.

This README is meant to be the one place you go to understand what the project is, how it's built, and how the engine actually executes a script. Treat it as the repo's bible — if something here drifts from the code, fix it here.

## Which Jac are we building against?

This is the part that trips people up, so read it carefully.

js_engine is **not** built against a released `jaclang`. It is built with the Jac compiler in this repository (`../jac/jaclang`), because it depends on native-backend fixes that may not be in any release yet. The compiler and the engine come from the same checkout: check out a different commit and you have changed the compiler underneath the engine.

Build the in-repo compiler once, with its sources linked from the checkout, and put it first on `PATH`:

```bash
(cd ../jac && zig build -Ddev)
export PATH="$PWD/../jac/zig-out/bin:$PATH"
```

## Building

Everything runs through the [Makefile](Makefile), from inside the `js_engine/` directory.

### One-time setup

js_engine links a few system C libraries. Two of them are version-sensitive and the Makefile will fetch and build them for you: PCRE2 10.45 (we need its variable-length lookbehind support) and llhttp 9.4.1. The rest — libuv, OpenSSL, zlib, nghttp2 — are expected from your system package manager.

```bash
make install_deps     # builds PCRE2 10.45 (needs sudo) and llhttp 9.4.1 (local, no sudo)
```

For reference, the library versions we expect to be linked against:

| Library | Version | What it's for |
|---------|---------|---------------|
| libuv | 1.48.0 | event loop, async I/O, timers |
| OpenSSL | 3.0.13 | crypto, TLS |
| zlib | 1.3 | compression |
| PCRE2 | 10.45 | the RegExp engine |
| llhttp | 9.4.1 | HTTP/1.1 parsing |
| nghttp2 | 1.59.0 | HTTP/2 |

### Compiling the engine

```bash
make build      # incremental build → bin/js_engine
make scrub      # full rebuild from scratch (wipes the IR cache)
make clean      # remove bin/, lib/, and every .jac_ir/ cache
```

`make build` is really just this under the hood:

```bash
jac nacompile engine/src/main.na.jac -o bin/js_engine
```

The compiler caches per-module LLVM IR in `.jac_ir/` directories alongside the source. That's why incremental builds are quick — and it's also why `make scrub` exists, for the occasions when the cache lies to you. The result is one standalone binary: **`bin/js_engine`**.

## Running

```bash
make run FILE=path/to/script.js     # run a JS file
./bin/js_engine path/to/script.js   # or just call the binary directly
```

If you want to peek inside the pipeline while running a file, flip the flags in the `with entry` block at the top of [engine/src/main.na.jac](engine/src/main.na.jac):

- `FLAG_AST` — print the parsed AST
- `FLAG_BC` — print the disassembled bytecode
- `FLAG_RUN` — actually execute the script
- `FLAG_DEBUG` — print file info, timing, and other diagnostics

## How the engine works

At the highest level, a script flows through four stages — lex, parse, compile, execute:

```
 source text (.js)
     │  parser/lexer.na.jac        →  tokens
     │  parser/parser.na.jac       →  AST            (parser/ast.na.jac)
     │  bytecode/compiler.na.jac   →  CompiledFunction[]   (bytecode/op.na.jac)
     ▼  vm/vm.na.jac               →  runs the bytecode under the event loop
   result
```

Two systems sit alongside that pipeline and touch every stage:

- **The value model** (`runtime/jsvalue.na.jac`). Every JS value is a single NaN-boxed 64-bit integer, JSC-style. There's no struct and no tagged enum at the value level — integers, doubles, booleans, `null`, `undefined`, and handles to heap cells (strings and objects) are all packed into one 64-bit register. Everything past the parser speaks `JSValue`.
- **Native dispatch** (`builtins/dispatch.na.jac` and the native registry). This is the bridge that turns a function written in Jac into something callable as a JS function on the global object.

The binary is launched from [engine/src/main.na.jac](engine/src/main.na.jac), and the little "parse → compile → run" convenience wrapper is `run_script()` in `runtime/global.na.jac`.

### The lexer — `parser/lexer.na.jac`

Hand-written, single-pass, and deliberately uses no regex. It turns source text into a flat stream of tokens, each carrying its type, raw text, 1-based line/column, and a `has_newline_before` flag.

A couple of things make it more than a trivial scanner. Whether a `/` begins a regexp or means division can't be settled from the token stream alone, so the *parser* tells the lexer what's coming by calling `set_regexp_mode()` after each token; template literals are stateful in the same way. And the lexer doesn't insert semicolons for ASI — it just records `has_newline_before` and lets the parser decide. Identifiers are ASCII-only for now; full Unicode identifiers aren't implemented yet.

### The AST — `parser/ast.na.jac`

The AST uses a single "fat node": one `ASTNode` type that carries *every* field any node could ever need. A given node fills in only the fields relevant to its kind and leaves the rest at their defaults. It's a deliberate trade — native compilation wants a fixed, predictable LLVM struct layout, and Jac Native doesn't give us an ergonomic tagged union or inheritance to model node variants, so we spend some memory to get a flat layout. `ASTNodeType` enumerates every node kind.

### The parser — `parser/parser.na.jac`

Recursive descent with a Pratt (operator-precedence) expression parser on top. It consumes the token stream and builds the AST, and it covers the modern JS surface: classes, destructuring, spread and rest, optional chaining, template literals, generators, async/await, and modules. It's the biggest file on the front end.

### The bytecode compiler — `bytecode/compiler.na.jac` + `bytecode/op.na.jac`

This walks the AST and emits bytecode into `CompiledFunction` objects. `op.na.jac` defines the opcode set and the `disassemble()` routine that backs `FLAG_BC`. Every JS function — including the top-level program itself — compiles to its own `CompiledFunction`.

### The virtual machine — `vm/vm.na.jac`

The interpreter that executes the bytecode over the `JSValue` model. By a wide margin it's the largest file in the repo, because this is where the real work lives: the object model, prototype chains, closures and their captured cells (`vm/cell.na.jac`, `vm/closure_type.na.jac`), and dispatch out to the native builtins.

### The event loop — `vm/event_loop.na.jac`

`el_run(source, script_name, extra_args)` is the true top-level entry point, and it owns the whole lifecycle of a run:

1. Build the `GlobalContext` and initialize the builtins.
2. Spin up the libuv event loop.
3. Run the top-level script synchronously (this is where parse → compile → execute happens).
4. Enter `uv_run(UV_RUN_DEFAULT)` and block until every referenced handle has closed. The script finishing isn't enough to end the process — only live handles like timers, fs operations, and sockets keep the loop alive, exactly as Node and Bun behave.
5. Flush the final callbacks, close the handles, and return.

One subtlety worth knowing: for a normal run, `main.na.jac` doesn't parse and compile the script itself, because `el_run` already does that internally via `run_script`. The standalone parse/compile calls you see in `main.na.jac` are only there to feed the `FLAG_AST` and `FLAG_BC` debug printers.

### Memory — `runtime/gc.na.jac`, `runtime/gc_mark.na.jac`

Every `obj` allocation is GC-managed; there's no manual `free` anywhere. Struct fields are traced automatically, so you never have to register roots by hand.

## Repository layout

```
js_engine/
  Makefile                 # build / run / test entry point
  engine/
    src/
      main.na.jac          # binary entry point + the AST/bytecode debug printers
      version.na.jac       # version constants (js_engine, Node compat target, linked libs)
      parser/              # lexer.na.jac, ast.na.jac, parser.na.jac
      bytecode/            # compiler.na.jac, op.na.jac
      vm/                  # vm.na.jac, event_loop.na.jac, scheduler, timers, cells
      runtime/             # jsvalue, jsstring, jsobject, heap, gc, global, realm, ...
      builtins/            # native builtins (.na.jac) + JS-side modules (js/*.js)
      ffi/                 # C bindings: libuv, libssl, libcrypto, zlib, libpcre2,
                           #   libllhttp, libnghttp2, libc, libm, libdl
      httpcore/ net/ tls/ ws/   # networking stacks
  napi/                    # N-API ABI shim + bindings (Node native-addon compat)
  bin/js_engine            # build output (gitignored)
```

The N-API layer under `napi/` needs the Node headers at `/usr/include/node` and builds a shim shared library, `lib/libnapi_shim.so`.

## Status

js_engine is pre-alpha — version `0.1.0`. A large chunk of the JS language and the Node.js API works today, but plenty is still stubbed or partial: `eval()`, the `encodeURI`/`decodeURIComponent` family, some `Array` callback paths, full Unicode identifiers, switch fall-through, and computed `delete`, among others. Expect rough edges, and check the source before assuming a given feature is complete.
