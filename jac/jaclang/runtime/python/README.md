# Python compiler replacement

JacPython compiles Python source and ASTs using native Jac machine code in
every distribution. CPython provides Python objects and the execution engine.
Selected standard-library extension modules also use native Jac implementations.

| Location (from repository root) | Responsibility |
| --- | --- |
| `jac/jaclang/compiler/frontend/python/` | Python scanning, parsing, AST validation, source decoding, and symbol analysis |
| `jac/jaclang/compiler/backends/py/jacpython/` | Native request handling, bytecode generation, assembly, and code-object serialization |
| `jac/jaclang/runtime/python/` | Compiler values, tokenizer/symbol-table interfaces, shared object API, and native standard-library modules |
| `jac/jaclang/runtime/python/bindings/` | Native module/type declarations, argument binding, descriptors, and Python object ownership |
| `jac/bootstrap/python/` | Pinned source build and shared C shims for opaque CPython ABI records and object APIs |

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

`modules/` contains the native standard-library algorithms. `bindings/` implements
all sixteen module adapters in native Jac, including their `PyInit_*` entry points,
constructors, descriptors, protocol callbacks, and lifecycle handling. There are
no per-module C adapters. `capi.jac` declares shared retained-object operations;
`bootstrap/python/object_api.c` implements those C API primitives, while
`bootstrap/python/binding_api.c` stores opaque CPython module, type, and buffer
records without module-specific policy.

Declarations contain no Python objects and live for the process lifetime. Each
interpreter owns its module state and heap types. Owned argument frames release
conversions on success and error paths. A shared native-state protocol exposes
Python reference edges to the cycle collector, while Jac retains and releases
native state. Buffer exports retain their owner and their own layout metadata.
Python calling conventions and isolated interpreters are preserved.

Queues and deques share `modules/object_ring.jac`. Its circular storage transfers
owned Python references without invoking callbacks; callers finish mutations
before releasing references. The binding callbacks expose every retained Python value
to CPython's cycle collector. Native objects report actual allocation sizes,
including owned storage, rather than the layout sizes of the replaced C types.
The compatibility runner excludes the upstream deque test that hard-codes that
C layout; the runtime smoke checks allocation growth and reclamation instead.

`modules/math.jac` and `modules/cmath.jac` share the platform libm interface in
`modules/numeric.jac`. Integer algorithms use retained CPython integer operations;
there is no second arbitrary-precision runtime for these modules. Accurate
summation, vector norms, and dot products use native error-free transforms.

`modules/functools.jac` implements partial argument binding, reductions,
comparison keys, and cache policy. Bounded caches reuse the retained runtime's
ordered dictionary; native binding state stores cached hashes and visits references.
There is no separate native hash table or Python cache-policy callback.

Iterator policies live in `modules/iterators.jac`, `combinatorics.jac`,
`grouping.jac`, and `tee.jac`. Shared tee replay blocks have one CPython GC owner
per block, so multiple cursors do not report duplicate reference edges. Tuple
reuse preserves callback safety. As with deque, the four upstream iterator
size tests describe the retired C layout; smoke tests check native storage
accounting instead.

`modules/array.jac` shares endian-aware scalar operations with `struct` through
`modules/binary_scalars.jac`. Its buffer uses retained CPython bytearray storage;
Jac owns resizing, slicing, conversion, iteration, and pickle reconstruction.
Exported memoryviews pin the logical size, and conversion finishes before an
address is taken so user callbacks cannot invalidate a saved buffer pointer.
Array size reporting includes the Jac state and actual retained buffer allocation.

`modules/pickle.jac` exposes typed reader/writer state. `pickle_encode.jac` and
`pickle_decode.jac` implement all six protocols, memoization, object reductions,
and callbacks; `pickle_stream.jac` owns framing and bounds checks, while
`pickle_objects.jac` resolves globals and compatibility mappings. Retained
CPython dictionaries store memo entries, and buffer objects keep their existing
Python ABI. Shared serialization error notes live in `capi.jac`, also used by
JSON. The two upstream pickle size assertions describe retired C layouts;
smoke checks cover native memo allocation, reclamation, and callback cycles.
