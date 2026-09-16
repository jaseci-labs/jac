# C frontend

`parser.parse_c(source, file_path, config)` preprocesses and parses a configured
C translation unit into the graph-linked C nodes in `../unitree_c.jac`.
The implementation is Jac; it does not invoke a host C compiler or use a foreign
parser. Include directories and predefined macros are explicit inputs.

This is an initial frontend, **not a complete C compiler or CPython migration
pipeline**. `CParseResult.ok` reports preprocessing and syntax diagnostics. It
does not establish C type correctness, ABI compatibility, or executability.
The C nodes are not accepted directly by the existing native backend. The
`jac tool c2jac` command emits ordinary Jac source for the supported subset; it does not enable `.c` inputs in the normal compilation schedules.

```jac
import from jaclang.compiler.frontend.c.parser { parse_c }
import from jaclang.compiler.frontend.c.preprocessor { CConfig }

with entry {
    result = parse_c(
        '#include "counts.h"\n#define CAPACITY 16\n'
        'static size_t bump(size_t n) { return n + CAPACITY; }\n',
        "example.c",
        CConfig(virtual_headers={"counts.h": "typedef unsigned long size_t;"})
    );
    for diagnostic in result.diagnostics {
        print(str(diagnostic));
    }
    # result.tree is a CTranslationUnit, not a backend-ready Jac Module.
}
```

## Representation

All C nodes derive from `UniNode`, with graph-linked operands under
`ChildrenRole`, ordinary UniTree token anchors, and source locations. The root
contains a `CPreprocessingUnit` followed by declarations. Preprocessing nodes
retain directive tokens, whitespace separation, active/inactive flags, and
inactive source text. Included operations appear in processing order. The
original source of each file is also retained in `preprocessing.sources`.
Expanded tokens carry macro expansion names, hide sets, physical source
locations, and presumed locations for `#line`.

| Node | Contents |
| --- | --- |
| `CTranslationUnit` | Preprocessing program and selected declarations |
| `CPreprocessingUnit` | Ordered directive and source-text operations |
| `CPreprocessorDirective` | Directive kind and original preprocessing tokens |
| `CPreprocessorText` | Active or inactive source tokens |
| `CTypeSpec` | Specifier sequence, qualifiers, storage, records, enums, atomic and alignment forms |
| `CDeclarator` | Pointer layers, grouping, arrays, functions, names and abstract declarators |
| `CDeclaration` | Declarations, parameters, enumerators, function definitions and static assertions |
| `CExpression` | Explicit C operators, literals, calls, casts, initializers and generic selections |
| `CStatement` | Blocks, selection, loops, jumps and labels |

Declarator grouping is preserved. For example, `int *f(void)` and
`int (*f)(void)` have different trees. `declarators.derived_operators` orders derived
type operations from the identifier outward. A declaration with multiple
init-declarators has one specifier child followed by its init-declarators.
Function declarators have their direct declarator first, followed by parameters.
Literal spellings and operator identities remain C spellings: implicit casts,
integer promotions, pointer arithmetic, assignment values, and signed overflow
must be resolved by a C semantic pass before lowering.

## Jac source emission and CLI

```sh
jac tool c2jac input.c -o output.jac
jac tool c2jac input.c -I include -I vendor/include -D FEATURE=1 --abi lp64
jac tool c2jac - --abi llp64 --unsigned-char < input.c > output.jac
jac tool c2jac --help
```

For a C file that is included by another `.c` file, supply the complete
translation unit and select the desired source as an emission root:

```sh
jac tool c2jac owner.c --select-source included.c -I include -o included.jac
```

`--select-source` may be repeated. Parsing and name resolution still use the
complete translation unit. Emission retains selected definitions and their
internal-linkage function/global initializer dependency closure. Externally linked definitions owned by other
source files remain typed imports; those files must supply the corresponding
linker symbols and initialization. Selection does not import unrelated constructors
or duplicate the surrounding translation unit. A selected path with no active
declarations produces a diagnostic.

Output defaults to stdout; diagnostics go to stderr. `-I` and `-D` can be
repeated, and `-D NAME` means `NAME=1`. `-` reads stdin or selects stdout. Named
output files are replaced atomically only after successful emission. The input
file cannot also be the output, including through a symlink or hard link.
Argument errors return 2, translation/I/O errors return 1, and success returns 0.

The corresponding API is
`jaclang.compiler.tools.c2jac.emit_c(source, file_path, preprocess, config)`.
`preprocess` is a `CConfig`; `config` is a `CEmitConfig`. The result contains
`source`, `module`, `origins`, `diagnostics`, and `ok`, plus the shared
`PassResult.errors_had` and `warnings_had`. Diagnostics are compiler `Alert`
objects, rendered through the existing diagnostic formatter. On a lowering
error, `source` is empty and no partial output module is returned. Neither the
API nor command executes the resulting Jac.

The conversion follows the existing compiler layers:

```text
frontend/c: scanning, preprocessing, C syntax, integer-model rules
    -> passes/c_lower_pass: C semantics to standard Jac Module
    -> tools/c2jac: shared unparse_module and formatting
    -> cli/commands/transform: arguments and I/O
```

`passes.c_lower_pass.lower_c(parsed, config)` exposes the lowering result
without source emission. The output contains ordinary `Ability`, `Assignment`,
`FuncCall`, `IfStmt`, `WhileStmt`, and other existing UniTree nodes. Boolean
and conditional operands use the existing `CfgExpr` wrappers. The frontend
`jac_ast.jac` helpers construct these nodes directly; no intermediate Jac
source is parsed to manufacture the output tree. C integer promotion and
conversion rules and declaration types live separately in `semantics.jac`.
`declarations.jac` resolves those types, preserving qualifiers, record identity,
array bounds, and function signatures. `constants.jac` evaluates integer-only
constant expressions with C promotions, widths, wrapping, division rules, and
integer casts resolved through the same declaration resolver. Known scalar,
pointer, and fixed-array sizes also share a single resolver path for `sizeof`,
including constant array bounds. Enumerator constants use this evaluator too.
Enum objects retain nominal C identity during type resolution and emit their
configured integer representation. Record tags, typedefs, and constant names
share lexical declaration scopes, including function parameter scopes.
Parser and resolver share declarator
topology in `declarators.jac`. Source formatting and
punctuation belong to the shared normalizer/unparser/formatter.

Output tokens belong to a single generated source so the unparser's annex
filter does not discard declarations originating in C headers. `origins`
maps lowered node identities to original C `Span`s. Duplicated loop-step
statements are detached graph copies, not multiply-parented AST nodes.
Scanner/parser diagnostics remain frontend data until the lowering boundary,
where they become shared alerts (`E0090`/`W0090`); unsupported lowering uses
`E2290`. C syntax nodes remain a frontend representation. The executable
output module does not contain those C-specific nodes.

The emitter supports integer and `_Bool` scalar types, scalar typedefs,
globals, local typedefs, function definitions/prototypes, direct calls to functions defined in
the same translation unit, supported external prototypes, scoped locals, casts, arithmetic/comparisons,
short-circuit and conditional expressions, ordinary ASCII character constants and byte string literals,
`sizeof` of supported scalar, pointer, and fixed-array types and expressions,
assignments/increments as statements, and `if`, `while`, `do`, and `for` loops.
Loop lowering preserves the increment/condition behavior of `continue`.
Unused function prototypes do not produce Jac declarations.

C names at module scope acquire a `c_` prefix (`add` becomes `c_add`). Local
names receive unique identifiers so C block shadowing remains distinct in Jac.
`main` becomes `c_main`; no automatic entry block is emitted. Supported file-scope typedefs
are emitted as Jac type aliases, with their resolved types used in signatures.
Local typedefs participate in lexical type resolution without runtime statements.

`--abi` selects LP64 (default), LLP64, or ILP32 integer widths and ranks. These
models assume 8-bit bytes, 16-bit shorts, 32-bit ints, 64-bit long longs,
two's-complement narrowing, and arithmetic signed right shift. Plain `char` is
signed unless `--unsigned-char` is supplied. This option does not configure a
native compiler target or supply platform/compiler predefined macros.
`--enum-model gnu` (default) uses unsigned 32-bit enum storage when every value
is nonnegative, and signed 32-bit storage otherwise; `int32` always uses signed
32-bit storage. These are explicit policies, not an inference from LP64/LLP64.
Short enums, wider enum ranges, and wide extended enumerator expressions remain
unsupported. See [GCC's enum rules](https://gcc.gnu.org/onlinedocs/gcc/Structures-unions-enumerations-and-bit-fields-implementation.html).

Integer promotions and usual arithmetic conversions are explicit. Unsigned
arithmetic uses Jac wrapping builtins; integer narrowing uses `.wrap`.
Signed division and remainder use generated helpers to retain C's truncation
toward zero. Signed arithmetic uses Jac's checked fixed-width operations;
executions with C undefined arithmetic behavior need not reproduce a C binary.
Uninitialized scalar local storage and scalar fallthrough return values are
zeroed; this is not a claim to diagnose all undefined C executions.

Byte strings use module-lifetime fixed arrays with a terminating zero byte;
array decay produces a raw pointer to that storage. Character-array initializers
use inline arrays directly, infer omitted bounds, zero-fill extra slots, and
omit the terminator when the declared array fits only the string characters.
Literal decoding follows C escape lengths, not host-language escape rules.
Non-ASCII source characters and wide/prefixed literals still require an explicit
execution-character-set model.
Predefined C function-name arrays (`__func__`, `__FUNCTION__`, and
`__PRETTY_FUNCTION__`) share the same static string-storage path, with one
binding per function and predefined name. GNU statement expressions whose
result is discarded lower through ordinary scoped statement lowering; their
internal branches and effects are retained.

Plain complete structs emit standard
UniTree archetypes using the new `struct` keyword; pointer and fixed-array types
emit `ptr[T]` and `array[T, N]` through the shared generic-index AST. Values retain
C declaration types through signatures, locals, globals, and returns. The
lowerer includes array decay, pointer indexing/dereference, address-of, field
access, pointer offsets, selected pointer conversions, and storage assignments.
Assignments, compound assignments, and prefix/postfix increments capture the
destination address once. Expression-valued updates call private typed helpers
that return the stored value (or the prior value for postfix updates), preserving
short-circuit and loop-condition evaluation. The same path handles discarded
assignment results. Repeated file-scope
object declarations are merged; referenced external objects use the existing
C-library import declaration syntax and native global-registration path.
C `_Thread_local` object declarations use `glob thread_local name: Type` (or
`glob:priv thread_local name: Type` for internal linkage). The modifier is
contextual, so a variable named `thread_local` remains legal. It is preserved
through UniTree, the shared unparser, and native imported/global registration.
Native definitions require unmanaged value storage and constant initializers;
other backends diagnose direct access instead of sharing the value. Static
locals are hoisted to private globals while their C names stay block-scoped.
File-static functions/objects, generated literals, and arithmetic helpers also
use Jac's existing private access modifier to retain internal linkage.
Incomplete C struct and union tags emit forward declarations such as
`struct Handle;`. These remain opaque in shared type metadata and
LLVM layout: `ptr[Handle]` has a known size, but `Handle` does not. Construction,
by-value parameters/returns/fields, array elements, and pointer operations that
need a pointee size are diagnosed. Pointer passing, null construction, and address
conversion remain available. Empty complete structs (`struct Empty {}`) are
separate from opaque declarations. Native layout export preserves raw addresses
without treating them as managed strings or object instances.

`size_of(Type)`, `align_of(Type)`, and `offset_of(Struct, "field")` query the
native target layout. C `offsetof` lowers to field-offset queries and element
size arithmetic, including nested members, anonymous member paths, and constant
array indices. The field-name argument is a literal and bitfields cannot be
queried with `offsetof`.

Anonymous struct members retain distinct nested storage while member access
follows their promoted field paths. Pointer equality supports integer null
constants and compatible qualified or void/object pointers.

Complete unions use a Jac value struct containing `overlay[T, U]` storage
(nested for additional alternatives). Member access uses typed pointer views
of the same storage, preserving field addresses and overlapping writes.
The shared native ABI layer measures alternative sizes and alignments through
LLVM target data; the C frontend does not implement a separate layout calculator.
Union initializers use private typed helpers to initialize the selected member;
ordinary aggregate initialization can still require module initialization code.
This storage representation does not yet supply C aggregate calling-convention
classification.

Packed records use nested `packed[T, U]` components inside a value struct. Each
component stores its two values consecutively with byte alignment; component
types retain their own internal layout. Field offsets sum the preceding fields'
native `size_of` values. Reads and updates use `ptr.load_unaligned()` and
`ptr.store_unaligned(value)`, including nested members, and preserve a single
evaluation of the destination address. Packed aggregate initializers, packed
bitfields, and packed array decay still produce diagnostics.

Object-level GNU `aligned(N)` declarations use `aligned[T, N]` storage with a
`.data()` pointer to the original value. The shared native ABI service verifies
its target alignment and supplies trailing padding. The C object's `sizeof`
still measures `T`, not the storage wrapper. Globals, static locals, automatic
locals, and imported object addresses retain this distinction. Field/type
alignment attributes still require a separate layout-aware translation.

Unsigned byte bitfields use shared byte allocation units, including partial
units and ordinary neighboring fields. Reads mask the selected bits; updates
capture the destination once and preserve all other bits, with volatile accesses
retained. Initializers combine the selected values into their allocation units.
This allocation model currently assumes GNU little-endian bit ordering.
Records consisting entirely of completely filled 32-bit integer bitfield units
can retain their layout as opaque `u32` fields. Access and initialization of
those wider bitfields still require further lowering.
Volatile declarations retain their ordinary storage representation and use
explicit volatile pointer loads and stores, including local initialization.
Combining volatile or atomic access with unaligned storage remains unsupported.

Scalar C atomics lower to the shared native pointer operations `atomic_load`,
`atomic_store`, `atomic_exchange`, `atomic_fetch_*`, and
`atomic_compare_exchange`. Memory orders are constant strings: `relaxed`,
`consume`, `acquire`, `release`, `acq_rel`, or `seq_cst`; an optional final boolean
marks a volatile operation. Compare-exchange accepts an expected-value pointer,
updates it on failure, and returns a boolean. Atomic compound assignments capture
their destination and right operand once, then use compare-exchange retries.

The current C atomic representation covers pointers and integer widths no larger
than the configured pointer width, using the native scalar storage representation.
Atomic booleans, floating values, aggregates, and unsupported target layouts still
require additional representation work. The native pointer operations require
addresses aligned to the scalar size. GNU generic atomic builtins use ordinary
typed pointers for their auxiliary buffers; unsupported order values or dynamic
order expressions produce diagnostics. GNU `__auto_type` inference supports a
single initialized local identifier, using the existing semantic expression types.

Diagnostic and optimization-only attributes, such as `unused`, `format`, and
`nonnull`, can be omitted without changing defined C execution. Their original
syntax remains available in the C tree. Unknown attributes and attributes that
affect storage, linkage, calling conventions, or initialization remain explicit
lowering requirements.

Function pointers emit `ptr[Callable[[...], Return]]`. Taking a named function's
address uses `addr_of`; indirect calls use `.call(...)`, whose checker signature
is specialized to the pointee's parameter and return types. Referenced external
functions use the same C-library declaration block as external objects. Native
raw calls currently accept fixed prototypes using 32-bit-or-wider integers,
`f32`, `f64`, raw pointers, and void returns. Narrow integer ABI attributes,
aggregate-by-value ABI classification, variadic function pointers/definitions, and closures still
need integration; they are not implied by source representation support.
These paths require
the updated native compiler; implementation checks do not establish end-to-end
CPython conversion or target ABI correctness.

Decimal and hexadecimal floating literals use `f32`/`f64`, including exact
binary32 literal rounding. Arithmetic emits explicit result conversions where
Jac's operator result type is wider. Long double, complex arithmetic, and floating
environment access still require further lowering.

Functions containing labels, `goto`, or `switch` use a typed control-flow graph
before Jac emission. Blocks become ordinary Jac branches in a dispatch loop;
automatic storage is declared outside the loop and initializers remain at their
original execution points. This preserves forward/backward jumps, switch
fallthrough and default selection, and distinct loop `continue` and switch
`break` destinations. Lexical names and types are resolved by the same lowerer
used for structured functions. Computed jumps and variable-length storage remain
unsupported.

GNU statement expressions that produce a value use the existing immediately
invoked lambda representation, including typed locals and captures of outer
storage. Expressions that transfer control outside that block remain diagnosed.
Record compound literals in value contexts use normal value-struct construction;
addressable compound-literal storage is not yet supported. Static address
constants retain their constant status through pointer offsets. `__builtin_expect`
retains its value and C `long` conversion while omitting the optimization hint.
`__builtin_clz`, `__builtin_clzl`, and `__builtin_clzll` reuse the existing Jac
`bit_length` primitive after shifting into a representable signed range. Constant
`__builtin_assume_aligned` promises preserve the pointer conversion and value.

Calls to declared external variadic functions use Jac's existing foreign
`*args` signature and native C ellipsis support. Fixed arguments retain their
declared types; trailing scalar arguments undergo C's default integer and
floating promotions, while pointers retain their native representation.
Aggregate arguments in the variadic tail require target ABI classification
and are diagnosed. Foreign pointer, array, and overlay annotations retain
their types through expression checking instead of degrading to `any`.

`--function-pointer-interop` permits implicit conversions between function
pointers and `void *`, as used by CPython's type and module slot tables. Use it
only for a target whose code and data pointer representations are interchangeable;
it emits the same typed address conversions used for explicit C casts. The
default rejects these implicit conversions rather than assuming this extension
on every target.

Header typedefs are resolved without emitting unused aliases. Header static
functions are emitted transitively when referenced; external definitions and
source-owned functions remain roots. GNU `extern inline` bodies are also selected
by reference, with private helper definitions and external function addresses.
When emitting a complete translation unit, constructor/destructor, retention,
and unknown attributes keep functions as roots so unsupported effects remain
diagnosed. Explicit source selection preserves the linkage boundary described
above. Attribute names are recorded by the C parser alongside their original
token payload; supported alignment arguments also retain parsed expressions.
Record emission follows the types actually
used by emitted declarations, plus records defined in the input source. All C
declarations still undergo semantic collection.

External function declarations with assembler symbol labels retain the actual
linker name in emitted imports and references. Compatible aliases share one
foreign declaration; conflicting signatures are diagnosed. Assembler labels
that are not representable as Jac identifiers and labels on definitions remain
unsupported.

Explicitly braced array and struct initializers use the shared native constructors.
Direct index/member designators select slots, omitted members zero-initialize, and
outer array bounds can be inferred from initializer lists. Nested designators,
promoted-member designators, and scalar brace elision still need a full subobject
initialization planner. Function and static-storage addresses remain constants
through array decay, member access, and address-of lowering.

Unsupported bitfield layouts and wider bitfield accesses, other nondefault layout attributes,
array bounds involving unresolved names or layout, unsupported aggregate initializer forms,
non-ASCII or wide character constants,
unsupported external-call ABIs, local extern declarations, computed jumps,
statement expressions with nonlocal control transfers, and other unimplemented forms are
diagnosed rather than emitted as placeholders. Emission resolves preprocessing
for one configuration; it does not yet reconstruct macros as Jac comptime
declarations or preserve a C ABI. Source locations for unsupported constructs
refer back to the C input. This is a conservative initial source-emission
surface, not the complete semantic pass needed for CPython.

## Implemented surface

The scanner handles trigraphs, line splicing, comments, digraphs,
preprocessing numbers, ordinary/prefixed string and character tokens, and
punctuators. Locations refer to the original physical source after splicing.

The preprocessor implements object/function macros, standard and GNU named variadic macros,
argument prescan, rescanning with hide sets, stringification, token pasting and
empty-argument placemarkers. It handles `define`, `undef`, `include`, conditional
directives, `error`, `line`, `pragma once`, `include_next`, and the `warning` extension.
GCC/Clang diagnostic pragmas are retained without affecting program semantics.
Incompatible macro redefinitions retain a warning and install the new definition.
`__has_include` and `__has_include_next` use the same configured header search as
include directives, without reading or processing the queried header.
`__FILE__` and `__LINE__` are built in. Target/compiler-specific predefined
macros must be supplied through `CConfig.defines`. Function-like predefined
macros can be supplied as source directives. `CConfig.typedef_names` supplies
compiler-provided type names such as `__builtin_va_list`. Feature queries
(`__has_builtin`, `__has_attribute`, `__has_feature`, `__has_extension`,
`__has_c_attribute`) consult `CConfig.features`, keyed by the complete query
(e.g. `__has_builtin(__builtin_expect)`); unspecified features return zero.

Quoted includes search the including directory before `include_paths`; bracketed
includes use `include_paths`. `virtual_headers` supplies in-memory headers.
There is no implicit host-system include search. A preprocessor instance resets
its macro environment for each translation unit. Include depth and macro
expansion count are bounded by configuration.

Preprocessing conditions use an explicit integer evaluator, with configurable
`intmax_width` (64 by default), signed/unsigned conversion, wrapping unsigned
arithmetic, C division/remainder, `defined`, short-circuiting and ternary
selection. Host-language `eval` is never used. Invalid evaluated arithmetic
produces diagnostics; skipped operands are still parsed.

The parser covers a substantial C11-style surface: typedef-sensitive declaration
parsing, nested pointer/array/function declarators, prototypes, records, unions,
enums, bit-field syntax, designated initializers, compound literals, generic
selection, casts, `sizeof`, `_Alignof`, `_Alignas`, `_Atomic`, static assertions,
assignment/comma/conditional expressions, blocks, loops, switches and labels.
Typedefs share a scoped namespace with ordinary identifiers.

The syntax frontend also preserves GNU attributes, declaration asm labels,
inline asm statements, `typeof`, statement expressions, omitted-middle
conditionals, case ranges, computed goto, extended floating types, `__int128`,
`__auto_type`, and typed `__builtin_va_arg`/`__builtin_offsetof`/
`__builtin_types_compatible_p` calls. GNU qualifier and inline spellings are
normalized, including `__thread` as `_Thread_local`. Attributes retain their token payload in explicit nodes; parsing
these extensions does not imply executable source lowering or ABI support.

## Remaining work

This is not an exhaustive C11 conformance claim. Important gaps include:

- Universal character names and execution-character-set handling; complete
  literal decoding and implementation-defined character constants.
- Old-style function definitions and identifier-list declarators.
- Complete GCC/Clang/MSVC extension grammars and target-specific semantics.
  Accepted extension nodes remain explicit lowering errors unless supported.
- C23 syntax and preprocessing additions such as `__VA_OPT__` and `embed`.
- `_Pragma` and semantic pragma effects beyond `once`. Unsupported active
  directives are errors rather than silently ignored ABI/layout changes.
- C semantic analysis: declaration constraints, symbol/linkage resolution, type
  compatibility, target layouts, constant evaluation and implicit conversions.
- Lowering preprocessing operations into Jac's existing `comptime` evaluator.
  Today preprocessing executes in this frontend's dedicated token interpreter;
  retaining directive nodes does **not** make them existing Jac comptime nodes.
- Complete C-to-Jac semantic coverage and direct `.c` input integration with
  the normal compilation schedules.

The lowering pass consumes explicit C operations and produces shared executable
nodes or reports a capability gap. C arithmetic must retain its declared widths
and conversion rules instead of becoming managed Jac arithmetic.
Inactive branches are retained as preprocessing tokens; they are not parsed as
C declarations under a configuration in which they do not exist.

## Checks

The coverage expansion uses 15 CPython 3.14.6 files selected from the bootstrap
manifest with seed `20260916`, against configured Linux headers. All 15 emit Jac
and pass the installed global `jac check --native-coverage` with an isolated
snapshot of the changed compiler and no module or callable demotions. Generated
files, configuration notes, and check logs are saved locally under
`_planning/samples/generated/`; the earlier runners and diagnostics remain under
`_planning/samples/validation15-*`.

`page-queue.c` is parsed through its actual `obmalloc.c` owner and selected for
emission, retaining internal helpers and importing externally linked dependencies.
The `osx/prim.c` wrapper includes shared Unix code; it was checked in the Linux
host configuration, not against a macOS SDK. These checks do not establish C
conformance, runtime equivalence, or complete C ABI compatibility. No generated
programs, runtime tests, or linking checks were run.
Use the installed binary outside the checkout when checking these sources:

```sh
repo=/path/to/j1
cd /tmp
JAC_NO_DEV_SOURCE=1 "$HOME/.local/bin/jac" check \
  "$repo/jac/jaclang/compiler/frontend/c/" \
  "$repo/jac/jaclang/compiler/frontend/unitree_c.jac" \
  "$repo/jac/jaclang/compiler/passes/c_lower_pass.jac" \
  "$repo/jac/jaclang/compiler/tools/c2jac.jac"
```
