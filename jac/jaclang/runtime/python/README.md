# Python compiler replacement

JacPython compiles Python source and ASTs using native Jac machine code in
every distribution. CPython provides Python objects, the execution engine,
and the standard library.

| Location (from repository root) | Responsibility |
| --- | --- |
| `jac/jaclang/compiler/frontend/python/` | Python scanning, parsing, AST validation, source decoding, and symbol analysis |
| `jac/jaclang/compiler/backends/py/jacpython/` | Native request handling, bytecode generation, assembly, and code-object serialization |
| `jac/jaclang/runtime/python/` | Compiler values, opcode metadata, streaming-tokenizer and symbol-table interfaces |
| `jac/bootstrap/python/` | Pinned source build and C adapters for retained CPython values and APIs |

`native_api.jac` connects source/AST requests to `product_compile.jac` and the
native parser, scanner, and symbol-table implementation. `marshal_writer.jac`
serializes code objects for CPython's retained marshal reader. No replacement
bytecode, embedded compiler seed, or Python dispatch callback is shipped.
The compiler image excludes these implementation directories from its ordinary
Python/JIR modules; their CPython license is retained.
The native implementation currently uses Jac's managed memory profile.

The build-time host is ordinary CPython. The checksum-pinned previous Jac builds
Stage 1, which uses the existing native backend to emit `jacpython.o` through
`bootstrap/compiler.jac`. This explicit build artifact must contain no interpreted
demotions and must pass LLVM verification. The runtime builder consumes that
object and links it with the retained C sources. It never imports compiler
sources or creates a renamed copy of the compiler.

`cpython-sources.txt` records the excluded C compiler inputs. The runtime build
checks that those sources and objects remain absent. Compiler changes invalidate
the native object through the normal build graph; the runtime fingerprint includes
the consumed object bytes and its source-build inputs.

Rebuild after editing the replacement:

```sh
cd jac
zig build
zig-out/bin/jac -c 'assert eval("6 * 7") == 42'
```

See [CONTRIBUTING.md](../../../../CONTRIBUTING.md#trying-the-jacpython-release-binary)
for the supported release workflow. The upstream compatibility
runner, `scripts/run_cpython_compiler_tests.jac`, downloads checksum-pinned
CPython tests and requires the native JacPython runtime. Build and test drivers
may use Python; replacement algorithms execute natively.

The AST, token model, PEG parser and opcode metadata derive from CPython 3.14.6
and are maintained directly in Jac. [`LICENSE.cpython`](LICENSE.cpython) applies
to the CPython-derived code across these packages.
