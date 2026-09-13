# Python compiler replacement

Every `zig build` compiles Python source and ASTs using native Jac machine
code. CPython still provides Python objects, the execution engine, and the
standard library. There is no optional interpreted replacement or alternate
shipped compiler.

| Location (from repository root) | Responsibility |
| --- | --- |
| `jac/jaclang/compiler/frontend/python/` | Python scanning, parsing, AST validation, source decoding, and symbol analysis |
| `jac/jaclang/compiler/backends/py/jacpython/` | Native request handling, bytecode generation, assembly, and code-object serialization |
| `jac/jaclang/runtime/python/` | Compiler values, tokenizer/symbol-table interfaces, shared object API, and native standard-library modules |
| `jac/bootstrap/python/` | Pinned source build and C adapters for retained CPython values and APIs |

`native_api.jac` connects source/AST requests to `product_compile.jac` and the
native parser, scanner, and symbol-table implementation. `marshal_writer.jac`
serializes code objects for CPython's retained marshal reader. No replacement
bytecode, embedded compiler seed, or Python dispatch callback is shipped.
The payload excludes these implementation directories from its ordinary
Python/JIR precompile; their CPython license is retained.
The native implementation currently uses Jac's managed memory profile.

The build-time host is ordinary CPython. `prepare_native.py` uses Jac's native
backend to emit the replacement object, rejects interpreted demotions, and
verifies LLVM IR before emission. Zig compiles the retained C sources and links
that object into the runtime. `cpython-sources.txt` records the excluded compiler
inputs; the build checks that those files and their objects remain absent.
Changes to the compiler, replacement sources, or build adapters invalidate the
JacPython build cache.

Rebuild after editing the replacement:

```sh
cd jac
zig build
JAC_NO_DEV_SOURCE=1 zig-out/bin/jac -c 'assert eval("6 * 7") == 42'
```

See [CONTRIBUTING.md](../../../../CONTRIBUTING.md#trying-the-jacpython-release-binary)
for downloading release binaries. The upstream compatibility
runner, `scripts/run_cpython_compiler_tests.jac`, downloads checksum-pinned
CPython tests and requires the native JacPython runtime. Build and test drivers
may use Python; replacement algorithms execute natively.

The AST, token model, PEG parser and opcode metadata derive from CPython 3.14.6
and are maintained directly in Jac. [`LICENSE.cpython`](LICENSE.cpython) applies
to the CPython-derived code across these packages.

`modules/` contains the native standard-library replacements. `capi.jac`
declares their shared retained-object operations; `bootstrap/python/object_api.c`
implements those C API calls. `bootstrap/python/modules/` contains Python
method/type registration and argument adapters. The algorithms are native Jac,
and their C sources and Clinic headers are excluded from shipped runtimes.

`bindings/` provides native Jac module declarations and argument binding. Bisect,
heapq, math, cmath, binascii, random, and queue use this path, including their `PyInit_*` entry points. The shared
`bootstrap/python/binding_api.c` stores opaque CPython ABI records without
module-specific policy. Declarations contain no Python objects and live for the
process lifetime; an owned argument frame releases conversions on success and
error paths. Python calling conventions and isolated interpreters are preserved.

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
ordered dictionary; the C boundary stores cached hashes and visits references.
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
