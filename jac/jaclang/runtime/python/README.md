# Python compiler replacement

`JACPYTHON=1 zig build` compiles Python source and ASTs using native Jac machine
code. CPython still provides Python objects, the execution engine, and the
standard library. Plain `zig build` uses stock CPython. The environment variable
selects the compiler at build time; each binary contains one runtime.

| Location (from repository root) | Responsibility |
| --- | --- |
| `jac/jaclang/compiler/frontend/python/` | Python scanning, parsing, AST validation, source decoding, and symbol analysis |
| `jac/jaclang/compiler/backends/py/jacpython/` | Native request handling, bytecode generation, assembly, and code-object serialization |
| `jac/jaclang/runtime/python/` | Compiler values, tokenizer/symbol-table interfaces, shared object API, and native standard-library modules |
| `jac/jaclang/runtime/python/bindings/` | Native module/type declarations, argument binding, descriptors, and Python object ownership |
| `jac/bootstrap/python/` | Pinned source build and shared C shims for opaque CPython ABI records and object APIs |

`native_api.jac` connects source/AST requests to `product_compile.jac` and the
native parser, scanner, and symbol-table implementation. Every request returns
a retained CPython value or raises its exception directly: `constant_output.jac`
builds constants and code objects through the object API and CPython's
validated code constructor, and `ast_output.jac` publishes trees with the
interpreter's own AST types and operator singletons. Strings and byte payloads
cross the boundary in single copies. No replacement bytecode, embedded compiler
seed, or Python dispatch callback is shipped. The payload excludes these
implementation directories from its ordinary Python/JIR precompile; their
CPython license is retained.

The native object is built with Jac's `rc` memory profile and the same LLVM
module pipeline as every other native artifact. Each compile request runs inside
one region, so the tokens, trees, symbol tables and code units it builds are
reclaimed together once its CPython result exists.

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
JACPYTHON=1 zig build
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

`modules/` contains the native standard-library algorithms. `bindings/` implements
all seventeen module adapters in native Jac, including their `PyInit_*` entry points,
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

`modules/statistics.jac` evaluates Wichura's AS241 inverse normal CDF over the
same libm interface. Its three coefficient pairs are applied by Horner's method
in the reference implementation's multiply-add order, and every comparison keeps
that implementation's orientation, so a NaN probability reaches the tail branch
and returns NaN rather than raising.

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

## Evaluator migration validation

The bytecode evaluator remains CPython's C implementation. Its replacement must
preserve the release performance baseline: `bootstrap/python/smoke.py` requires
the tail-call interpreter, `-O3`, and ThinLTO on Linux. Borrow checking by itself
does not establish equivalence of dispatch, stack-reference ownership, or
callback behavior.

Run execution compatibility through the existing pinned upstream test runner:

```sh
jac run scripts/run_cpython_compiler_tests.jac \
    --module test.test_generators --compile-tests --execution-tests
```

`--execution-tests` counts every selected test instead of classifying successes
without compiler calls as skips. Upstream skips still apply. This mode exercises
the linked evaluator; it does not claim that the evaluator has been replaced.
The native compiler bridge remains mandatory.

From the repository root, compare execution performance using the build-only
CPython host and a candidate runtime:

```sh
python3 scripts/python_evaluator_bench.py \
    --baseline jac/.python-build/jacpython/macos-aarch64.host/python/install/bin/python3.14 \
    --candidate jac/.python-build/jacpython/macos-aarch64/python/install/bin/python3.14 \
    --output /tmp/evaluator.json
```

The driver requires Python 3.11 or later and runs without Jac installed. Both
subjects must match `sources.json`. Only the baseline compiles the workload
corpus; both subjects receive the same marshalled code. Imports, compilation,
startup, and warmup are excluded from timing. Each sample uses a fresh process,
and baseline/candidate order alternates. Reports include runtime configuration,
source and bytecode hashes, raw paired samples, and result checksums. A ratio
above one means the candidate took longer. `--max-slowdown 1.05`, for example,
fails if any workload's median paired ratio exceeds 1.05; no threshold is applied
by default. This small suite is an initial regression screen, not a comprehensive
performance-neutrality or Python-compatibility claim.

The twelve Python workloads and their Jac harness tests live together under
`jac/tests/compiler/`. The Python fixture deliberately exercises Python syntax
and lifecycle semantics, including `except*`, `yield from`, coroutine suspension,
and finalizers that reenter Python while a container releases an element.
