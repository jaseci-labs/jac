# Native Frontend Pipeline: From Lexer to Full Parser

## Current State (This PR)

The native LLVM-compiled lexer is wired into the parser via `native_accel`, delivering ~1.5x parse speedup on files >10K chars. The property getter/setter codegen bug is fixed, enabling unitree.jac to compile natively (148 structs, 4,365 methods).

## What We Proved

The native compiler is far more capable than expected:

| Feature | Status | Evidence |
|---|---|---|
| Multi-inheritance (up to 8 parents) | ✅ | `Ability` has 8 parents, compiles fine |
| Diamond + MRO | ✅ | 332 native gen tests pass |
| Polymorphism + vtable | ✅ | Virtual dispatch works |
| Self-referential structs | ✅ | Tree nodes with `list[TreeNode]` |
| Dict symbol tables | ✅ | `dict[str, int]` with insert/lookup |
| **unitree.jac (full AST)** | ✅ | **148 structs, 4,365 methods, 960/963 succeed** |
| **parser.jac** | ✅ | **155 methods, all compile** |

## Why Full Native Parser Isn't Wired Up Yet

### The cross-module type boundary

The parser and lexer compile in **separate JIT engines** with separate type systems. The parser's `tokens` field is `List.i64*` (opaque pointers) while the lexer produces `List.ptr*` (Token struct pointers). Calling `parser.current()` natively returns `None` because the type mismatch prevents correct list access.

### The unitree construction problem

Profiling shows **73% of parse time** is Python object construction:

```
make_uni_token:      7ms  (UniToken creation)
UniNode.__post_init__: 6ms  (AST node init)
UniToken.__init__:   3ms  (token construction)
---
Subtotal:           16ms of 22ms parse time
```

The parser's `parse_if_stmt()`, `parse_expression()`, etc. construct `IfStmt(...)`, `BinaryExpr(...)`, etc. These are Python `unitree` objects. The native parser compiles these as opaque `i64` calls that don't link to any real constructor because unitree isn't in the same compilation unit.

### What would fix it

**Single-unit compilation**: if `lexer.na.jac`, `parser.jac`, and `unitree.jac` were compiled together in one native pass, all types would share the same LLVM context. Token types would match, unitree constructors would be native, and the entire parse pipeline would run in native code with zero Python boundary crossings.

This requires the native IR gen pass to support **multi-module compilation** — compiling a set of `.jac` files into a single LLVM module. The cross-module import mechanism (`_walk_imported_module`) already handles some of this for `.na.jac` imports, but it doesn't merge the full type systems.

## Recommended Next Steps

### 1. Multi-module native compilation (highest impact)

Add a compilation mode where the native pass processes multiple modules into one LLVM context:
- `lexer.na.jac` + `tokens.na.jac` → Token types
- `unitree.jac` → 148 AST node structs + methods  
- `parser.jac` → Parser struct + 155 methods

All share one type system. The parser can natively construct unitree nodes, access token fields, and traverse the token list — zero Python overhead.

Expected: **5-10x full parse speedup** (eliminates all Python object construction during parsing, single conversion at the end).

### 2. Fix 3 remaining codegen failures

`Module.make_stub`, `Module.get_href_path`, and `Name.gen_stub_from_node` fail due to:
- List type mismatch in `get_href_path` (`List.ptr*` vs `List.i64*`)
- Constructor arg count mismatch in `make_stub` and `gen_stub_from_node` (likely related to default parameter handling)

### 3. Native-to-Python AST conversion

After native parsing, convert the native flat AST to Python unitree objects in one pass. This is the only Python boundary crossing, and it happens once per parse (not per-token or per-node during parsing).

## Files Changed in This PR

- `jac/jaclang/jac0core/native_accel.jac` — Native tokenize installation
- `jac/jaclang/jac0core/parser/parser.jac` — `_native_tokenize` hook
- `jac/jaclang/compiler/passes/native/na_ir_gen_pass.impl/objects.impl.jac` — Property getter/setter fix + param guard
