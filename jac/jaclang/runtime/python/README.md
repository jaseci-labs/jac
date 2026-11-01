# Python compiler replacement

JacPython is jac's Python runtime: its interpreter compiles Python source and
ASTs using native Jac machine code, and the objects, the evaluator and the
native standard-library modules are Jac as well. `zig build` builds it before
anything else (`zig build build-python` builds only the runtime), and every jac
binary bundles it.

| Location (from repository root) | Responsibility |
| --- | --- |
| `jac/jaclang/compiler/frontend/python/` | Python scanning, parsing, AST validation, source decoding, and symbol analysis |
| `jac/jaclang/compiler/backends/py/jacpython/` | Native request handling, bytecode generation, assembly, and code-object serialization |
| `jac/jaclang/runtime/python/` | Compiler values, tokenizer/symbol-table interfaces, shared object API, and native standard-library modules |
| `jac/jaclang/runtime/python/bindings/` | Native module/type declarations, argument binding, descriptors, and Python object ownership |
| `jac/jaclang/runtime/python/object_model/` | Native ports of `Objects/` files: interpreter types and objects defined under their C names |
| `jac/bootstrap/python/` | Vendored Python sources, the bootstrap seed pin, and the build's C API layout checks |

`native_api.jac` connects source/AST requests to `product_compile.jac` and the
native parser, scanner, and symbol-table implementation. Every request returns
a retained Python value or raises its exception directly: `constant_output.jac`
builds constants and code objects through the object API and the interpreter's
validated code constructor, and `ast_output.jac` publishes trees with the
interpreter's own AST types and operator singletons. Strings and byte payloads
cross the boundary in single copies. No replacement bytecode, embedded compiler
seed, or Python dispatch callback is shipped. The payload excludes these
implementation directories from its ordinary Python/JIR precompile; their
PSF license is retained.

The native object is built with Jac's `rc` memory profile and the same LLVM
module pipeline as every other native artifact. Each compile request runs inside
one region, so the tokens, trees, symbol tables and code units it builds are
reclaimed together once its Python result exists. A request can re-enter
native modules through the interpreter (the tokenizer imports `unicodedata` to decode
`\N{...}`); every binding callback is a Jac function C calls, which runs with
no current region, so module state and objects built there never land in the
request's region.

A build runs on an earlier JacPython: the previous build's output, an installed
runtime, or the checksum-pinned bootstrap seed of `bootstrap/python/seed.json`.
`prepare_native.py` uses Jac's native backend to emit the runtime object,
rejects interpreted demotions, and verifies LLVM IR before emission. Zig
compiles the C that remains (HACL* and the interpreter's `main`) and links that
object into the runtime. Changes to the compiler, replacement sources, or build
adapters invalidate the JacPython build cache.

Rebuild after editing the replacement:

```sh
(cd jac && zig build)
BIN="$PWD/jac/zig-out/bin/jac"
(cd "$(mktemp -d)" && "$BIN" -c 'assert eval("6 * 7") == 42')
```

The conformance runner, `scripts/run_python_conformance.jac`, runs the
vendored Python test suites in `jac/tests/python_conformance/` and requires the
native JacPython runtime. Build and test drivers may use Python; replacement
algorithms execute natively.

The AST, token model and PEG parser derive from Python 3.14.6 and are
maintained directly in Jac. The opcode metadata (`opcode_meta.jac`, and the
opcode headers and `Lib/_opcode_metadata.py` the build stages from
`bootstrap/python/generated/`) is generated from the instruction table in
`scripts/jacpython/instructions.jac` by `scripts/jacpython/gen_opcode_meta.jac`.
[`LICENSE.cpython`](LICENSE.cpython) applies to the code derived from Python's
C sources across these packages.

`object_model/` is Python's object model in Jac. `layouts.jac` declares the C
layouts (`PyObject`'s header, `PyTypeObject`, `PyNumberMethods`,
`PyLongObject`, ...) and the header constants their initializers use. It is
the input of the C API headers: every header under `Include/` (public,
`Include/cpython/` and `Include/internal/`) is staged from `bootstrap/python/generated/`, and
`scripts/jacpython/gen_include.jac` writes their structs and integer constants
from it, their declarations from `scripts/jacpython/capi_table.jac` and the
static strings from `scripts/jacpython/global_strings.jac`. A build fails on
a C API header in the vendored sources. `scripts/jacpython/gen_layouts.jac`
reads only `layouts.jac`: it computes the offsets and writes
`bootstrap/python/layouts_check.c`, which asserts every offset, size and
constant against the staged headers of each build. A module defines
its static type objects and singletons as C data under their C names
(`object_model/bool.jac` defines `PyBool_Type`, `_Py_FalseStruct` and
`_Py_TrueStruct`), so the interpreter's C code uses them unchanged. The ported
files are `boolobject.c`, `cellobject.c`, `namespaceobject.c`, `capsule.c`,
`iterobject.c`, `enumobject.c`, `sliceobject.c` and `rangeobject.c`
(`bool.jac`, `cell.jac`, `namespace.jac`, `capsule.jac`, `iterator.jac`,
`enumerate.jac`, `slice.jac`, `range.jac`), then `complexobject.c`,
`classobject.c`, `structseq.c`, `genericaliasobject.c`, `unionobject.c`,
`picklebufobject.c`, `interpolationobject.c`, `templateobject.c` and
`fileobject.c` (`complex.jac`, `method.jac`, `structseq.jac`,
`genericalias.jac`, `union.jac`, `picklebuffer.jac`, `interpolation.jac`,
`template.jac`, `file.jac`); `header.jac` holds the object header's inline
operations they share, reference counting included.

`modules/` contains the native standard-library algorithms. `bindings/` implements
every module adapter in native Jac, including the `PyInit_*` entry points,
constructors, descriptors, protocol callbacks, and lifecycle handling; the modules
are listed in `bootstrap/python/jacpython-modules.txt`. There are no per-module C
adapters. The HACL*-backed hash modules (`_md5`, `_sha1`, `_sha2`, `_sha3`,
`_blake2`, `_hmac`) call the vendored HACL* library, which stays C and is
linked from the archives the registry names. Jac calls the Python C API by its own
names: `python_capi.jac` is generated by `scripts/jacpython/gen_capi.jac` from the
headers a build stages and declares
every function and data symbol the sources use, with Python objects typed
`ptr[PyObject]`: exception objects are read in place (`PyExc_ValueError`) and
static types and singletons are used by address (`addressof(PyCode_Type)`,
`Py_None`).
`bindings/clinic/` is generated by `scripts/jacpython/gen_clinic.jac` from each
module's Argument Clinic signatures (`scripts/jacpython/clinic/<name>.jac`), and
calls the module's `_impl` functions with their C signatures;
`bindings/converters.jac` holds the generic clinic converters. The `jacpy_*`
helpers in `object_model/object_api.jac` and `compiler_objects.jac` give Jac
callers what the C API has as macros, static inline functions and object-layout
fields, and `object_model/binding_api.jac` stores opaque Python module, type,
and buffer records without module-specific policy; all keep their C names and
signatures. What differs between C libraries (the stat and dirent symbol
variants, errno, the stdio streams, CPUID, the macOS system log) comes from the
native floor (`compiler/backends/native/posix_floor.c`). Data
symbols, pointer arithmetic, in-place field access through a pointer, calls
through C function pointers, calls to variadic C functions (`fcntl`, `syslog`,
`PyTuple_Pack`, `Py_BuildValue`), and C functions with exact C names and structs
by value (`_PyAtExit_Init` returns a `PyStatus`) are written in Jac.

Declarations contain no Python objects and live for the process lifetime. Each
interpreter owns its module state and heap types. Owned argument frames release
conversions on success and error paths. A shared native-state protocol exposes
Python reference edges to the cycle collector, while Jac retains and releases
native state. Buffer exports retain their owner and their own layout metadata.
Python calling conventions and isolated interpreters are preserved.

Queues and deques share `modules/object_ring.jac`. Its circular storage transfers
owned Python references without invoking callbacks; callers finish mutations
before releasing references. The binding callbacks expose every retained Python value
to the interpreter's cycle collector. Native objects report actual allocation sizes,
including owned storage, rather than the layout sizes of the replaced C types.
The compatibility runner excludes the upstream deque test that hard-codes that
C layout; the runtime smoke checks allocation growth and reclamation instead.

`modules/math.jac` and `modules/cmath.jac` share the platform libm interface in
`modules/numeric.jac`. The libm functions that Zig's compiler-rt also defines
(log, log2, log10, exp, exp2, sin, cos, tan, fma) go through `jacpy_libm_*`
helpers in `object_model/object_api.jac`, which look them up in libSystem (libm on
Linux), because a Mach-O link otherwise binds them to compiler-rt's copies. As in Python, `gamma` and
`lgamma` use their own Lanczos evaluation rather than libm. Integer algorithms
use retained Python integer operations; there is no second arbitrary-precision
runtime for these modules. Accurate
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

`modules/itertools.jac` follows itertoolsmodule.c: every iterator type is a C
record with its own slots, created from a `PyType_Spec` when the module executes
and kept in the module state. Combinatoric iterators, `pairwise` and
`zip_longest` reuse their result tuple while they hold its only reference, and
index arrays are `PyMem` blocks, so `__sizeof__` reports the C layout.

`modules/array.jac` shares endian-aware scalar operations with `struct` through
`modules/binary_scalars.jac`. Its buffer uses retained Python bytearray storage;
Jac owns resizing, slicing, conversion, iteration, and pickle reconstruction.
Exported memoryviews pin the logical size, and conversion finishes before an
address is taken so user callbacks cannot invalidate a saved buffer pointer.
Array size reporting includes the Jac state and actual retained buffer allocation.

`modules/pickle.jac` holds the Pickler and Unpickler objects, their memo
proxies and the module-level dump(s)/load(s). `pickle_encode.jac` and
`pickle_decode.jac` follow `Modules/_pickle.c` over C records: the encoder
keeps the pointer-keyed open-addressing memo table and a framed bytes output
buffer, the decoder an object stack, a mark stack and an index-keyed memo
array, reading straight from the input buffer or a prefetched file chunk.
dumps/loads run on stack-held records. The two upstream pickle size
assertions describe retired C layouts; smoke checks cover native memo
allocation, reclamation, and callback cycles.

`modules/datetime_*.jac` implement `_datetime`: calendar arithmetic and ISO
8601 parsing (`datetime_calendar.jac`), the shared accessors, constructors and
tzinfo helpers (`datetime_objects.jac`), strftime preprocessing
(`datetime_format.jac`) and one file per type. The types, the UTC singleton and
the datetime C API capsule are static C data with `Include/datetime.h`'s
layouts, because C extensions such as `_zoneinfo` read them through the header's
macros; `bindings/datetime.jac` readies them for each interpreter and defines the
module.

`modules/decimal_*.jac` implement `_decimal` over libmpdec, which stays the C
library the build links (`-lmpdec`) and is declared in `modules/mpdecimal.jac`.
A Decimal keeps its `mpd_t` and a four-word static coefficient inside the object
and a Context its `mpd_context_t`, laid out as `_decimal.c`'s structs, so
libmpdec works on them in place. `decimal_objects.jac` holds the layouts, module
state, signal maps and the contextvar-based current context,
`decimal_convert.jac` the conversions, `decimal_number.jac` the Decimal type,
`decimal_context.jac` Context, SignalDictMixin and the context manager, and
`decimal_ops.jac` names the libmpdec operation each method family applies. The
heap types come from `PyType_Spec`s of C data in `bindings/decimal.jac`, each spec
its type's token.

`modules/socket*.jac` implement `_socket`. A socket object is a
`PySocketSockObject` in place (its layout, with `PySocketModule_APIObject`, is
generated from the pinned archive's `Modules/socketmodule.h`), so the
`_socket.CAPI` capsule hands `_ssl` the same type and fields as the C module.
`socket_core.jac` holds the module state, errors and `sock_call_ex()`, whose C
callbacks are `SocketCall` records run with the GIL released;
`socket_address.jac` converts addresses (`getsockaddrarg`, `makesockaddr`,
`setipaddr`); `socket_object.jac` the socket type with ancillary data;
`socket.jac` the module functions. Arguments go through the interpreter's own
`PyArg_ParseTuple()` family with the C formats. `socket_platform.<os>.jac`
declares what differs between C libraries (sockaddr length bytes, `msghdr` and
`cmsghdr` widths, `CMSG_*` alignment, `gethostbyname_r()` or the netdb lock,
`accept4()`) and which address families the target has; `socket_constants` is
generated by `gen_constants.jac`.

`modules/hashopenssl.jac` and `modules/ssl*.jac` implement `_hashlib` and
`_ssl` over the vendored OpenSSL, whose functions `modules/openssl.jac`
declares and whose macro values and error tables `gen_openssl.jac` generates
(`openssl_constants.jac`, `ssl_errors.jac`). `ssl_core.jac` holds the module
state, the native state of `_SSLContext`, `_SSLSocket`, `MemoryBIO`,
`SSLSession` and `Certificate`, SSL error reporting with `_ssl.c`'s line
numbers, and `PySSL_select()`; `ssl_cert.jac` decodes certificates;
`ssl.jac` has the clinic `_impl` functions and the OpenSSL callbacks (SNI,
ALPN, message, keylog, password, PSK). `ssl.SSLError` is a C-data
`PyType_Spec` over `OSError` whose `tp_str` reads `PyOSErrorObject` in place.
`_hashlib` caches fetched `EVP_MD`s in its module state and shares
`hashlib.jac`'s `HashLock` and `compare_digest()` with the HACL* modules and
`_operator`.

`modules/posixsubprocess.jac` converts every `fork_exec()` argument into C
memory before forking: argv, envp and the executable list as char* arrays,
the descriptors to keep, the group list, the child's messages and scratch
buffers, all reached from one C-layout record. Between fork and exec the child
runs only scalar and pointer arithmetic over that record and
async-signal-safe C calls, so it allocates nothing (the user's `preexec_fn`
aside, as in C). On Linux the child may start with `vfork()`; the native
backend declares `vfork` `returns_twice`, as clang does, so the function that
calls it is never inlined and its frame stays valid for the parent's return.
Descriptor listing, `struct termios` and `struct flock` layouts are per-OS
(`*_platform.<os>.jac`, `*_records.<os>.jac`).

## Evaluator migration validation

The bytecode evaluator is Jac (`interpreter/ceval.jac` and the instruction
handlers in `interpreter/ops*.jac`). It must preserve the release performance
baseline: `bootstrap/python/smoke.py` requires the tail-call interpreter, `-O3`,
and ThinLTO on Linux. Borrow checking by itself does not establish equivalence
of dispatch, stack-reference ownership, or callback behavior.

Run execution compatibility through the conformance runner:

```sh
jac run scripts/run_python_conformance.jac \
    --module test.test_generators --compile-tests --execution-tests
```

`--execution-tests` counts every selected test instead of classifying successes
without compiler calls as skips. Upstream skips still apply. This mode exercises
the linked evaluator; it does not claim that the evaluator has been replaced.
The native compiler bridge remains mandatory.

From the repository root, compare execution performance using an earlier
JacPython build (the bootstrap seed, for example) and a candidate runtime:

```sh
python3 scripts/python_evaluator_bench.py \
    --baseline /path/to/baseline/python/install/bin/python3.14 \
    --candidate jac/.python-build/macos-aarch64/python/install/bin/python3.14 \
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
