# C frontend

`parser.parse_c(source, file_path, config)` preprocesses and parses a configured
C translation unit into the graph-linked C nodes in `../unitree_c.jac`.
The implementation is Jac; it does not invoke a host C compiler or use a foreign
parser. Include directories and predefined macros are explicit inputs.

This is an initial frontend, **not a complete C compiler or CPython migration
pipeline**. `CParseResult.ok` reports preprocessing and syntax diagnostics. It
does not establish C type correctness, ABI compatibility, or executability.
The C nodes are not accepted by the existing native backend. No `.c` CLI routing
has been enabled.

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
`int (*f)(void)` have different trees. `CParser.derived_operators` orders derived
type operations from the identifier outward. A declaration with multiple
init-declarators has one specifier child followed by its init-declarators.
Function declarators have their direct declarator first, followed by parameters.
Literal spellings and operator identities remain C spellings: implicit casts,
integer promotions, pointer arithmetic, assignment values, and signed overflow
must be resolved by a C semantic pass before lowering.

## Implemented surface

The scanner handles trigraphs, line splicing, comments, digraphs,
preprocessing numbers, ordinary/prefixed string and character tokens, and
punctuators. Locations refer to the original physical source after splicing.

The preprocessor implements object/function macros, standard variadic macros,
argument prescan, rescanning with hide sets, stringification, token pasting and
empty-argument placemarkers. It handles `define`, `undef`, `include`, conditional
directives, `error`, `line`, `pragma once`, and the `warning` extension.
`__FILE__` and `__LINE__` are built in. Target/compiler-specific predefined
macros must be supplied through `CConfig.defines`.

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

## Remaining work

This is not an exhaustive C11 conformance claim. Important gaps include:

- Universal character names and execution-character-set handling; complete
  literal decoding and implementation-defined character constants.
- Old-style function definitions and identifier-list declarators.
- GCC/Clang/MSVC extensions, attributes, inline assembly, statement expressions,
  compiler builtins, and their target-specific semantics.
- C23 syntax and preprocessing additions such as `__VA_OPT__` and `embed`.
- `_Pragma`, `include_next`, and pragma effects beyond `once`. Unsupported active
  directives are errors rather than silently ignored ABI/layout changes.
- C semantic analysis: declaration constraints, symbol/linkage resolution, type
  compatibility, target layouts, constant evaluation and implicit conversions.
- Lowering preprocessing operations into Jac's existing `comptime` evaluator.
  Today preprocessing executes in this frontend's dedicated token interpreter;
  retaining directive nodes does **not** make them existing Jac comptime nodes.
- Lowering C nodes into shared executable UniTree operations, Jac source
  emission, and native-backend/CLI integration.

The next lowering boundary should consume the explicit C operations and either
produce shared executable nodes or report a capability gap. It must not turn
C arithmetic into managed Jac arithmetic merely because the syntax matches.
Inactive branches are retained as preprocessing tokens; they are not parsed as
C declarations under a configuration in which they do not exist.

## Checks

Only `jac check` was used during implementation. No parser execution, tests,
CPython compatibility runs, benchmarks, or other validation were run.
Use the installed binary outside the checkout when checking these sources:

```sh
repo=/path/to/j1
cd /tmp
JAC_NO_DEV_SOURCE=1 "$HOME/.local/bin/jac" check \
  "$repo/jac/jaclang/compiler/frontend/c/" \
  "$repo/jac/jaclang/compiler/frontend/unitree_c.jac"
```
