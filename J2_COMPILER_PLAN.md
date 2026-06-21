# Phase J2 — Compiler: C Callback Vtables in Clib Structs

**Status:** Deferred (design + spike captured here; no compiler changes landed).

**Parent plan:** [`PLAN.md`](PLAN.md) — Jac-Native Consolidation, Phase J2.

**Branch target:** Separate compiler branch (not `worktree-probe` / jac-desktop work).

---

## Goal

Delete `cef_shim.c` by expressing CEF vtables (`cef_app_t`, `cef_client_t`,
`cef_life_span_handler_t`, …) as Jac `clib` structs inside `import from libcef
{ }` blocks, with Jac `def` callbacks wired through C-ABI trampolines.

Prototype target: **`cef_life_span_handler_t`** (flat vtable, one meaningful
callback: `on_before_close` → `cef_quit_message_loop`).

---

## Why not pure Jac today (blockers)

| Blocker | Symptom | Notes |
|---------|---------|-------|
| `Callable = 0` defaults | E1001: Cannot assign int to Callable | C NULL is `0`; Jac treats `0` as `int`, not fn ptr |
| RC heap layout | Pointer passed to C may include RC header offset confusion | Flat clib structs skip nested layout; RC alloc adds header at ptr−8 (C sees body at ptr — OK for flat) |
| Nested clib sub-structs | Wrong C layout | C inlines `cef_base_ref_counted_t`; Jac nested `obj` fields are pointers |
| MEMORY-class aggregates (>16 B on SysV AMD64) | Passed incorrectly if not byval | `_codegen_clib_call` handles MEMORY via byval; flat vtable ~88 B needs pointer pass |
| Jac `def` ≠ C callback ABI | C calling Jac fn directly may break | Need explicit C→Jac trampolines with C signature |

**Current production path:** `cef_shim.c` → `libcef_shim.so` (scalar FFI only in
`cef.na.jac`). This remains correct until J2 is complete and validated.

---

## Prior art in the codebase

- **Clib structs:** `import from "lib.so" { obj Vec2 { has x: f64, ... } }` —
  fixtures in `jac/tests/compiler/passes/native/fixtures/clib_*.na.jac`
- **SysV ABI lowering:** `na_ir_gen_pass.impl/clib_abi.impl.jac` — MEMORY/byval,
  register coerces, `_clib_c_type`, `_clib_materialize_c_ptr`
- **Fn ptr → int coercion (native):** `type_evaluator.impl.jac` — Jac fn assignable
  to `int` in native context (for `uv_poll_start(..., cb)` pattern)
- **Jac fn ptr fields:** `callable_field.na.jac` — `Callable` in struct, indirect call
- **OSP trampolines:** `osp.impl.jac` — `_emit_osp_thunk` (different ABI: JacVal box)
- **Object vtables (Jac OOP):** `vtable.impl.jac` — inheritance dispatch, not C FFI

---

## Proposed compiler design (spike)

### 1. Type checker — null fn ptr defaults

**File:** `jaclang/compiler/type_system/type_evaluator.impl/type_evaluator.impl.jac`

Allow `int` → `Callable` (FunctionType dest) in native context when initializing
clib vtable fields:

```jac
# Null function pointer: int 0 → Callable in native clib vtable fields.
if isinstance(dest_type, types.FunctionType)
and isinstance(src_type, types.ClassType)
and src_type.is_builtin("int")
and self._in_native_context() {
    return True;
}
```

Alternative accepted in desktop binding today: declare fn-ptr slots as `int = 0`
(not `Callable`), assign Jac `def` at ctor time (fn coerces to i64). J2 should
support **both** `int` and `Callable[[...], ret]` slots.

### 2. Detect clib vtable structs

**Files:** `na_ir_gen_pass.jac`, `na_ir_gen_pass.impl/clib_vtable.impl.jac` (new),
`core.impl.jac`

After clib struct registration (pass 1.5 in `_process_clib_imports`), scan
`struct_field_types` for any `PointerType(FunctionType)` field → add struct name
to `clib_vtable_structs: set[str]`.

### 3. Vtable allocation — no RC header

**File:** `na_ir_gen_pass.impl/objects.impl.jac` — `_codegen_instantiation`

When `type_name in clib_vtable_structs`:

- **Do not** use `_rc_call_with_ctx` / RC dtor slot
- Allocate via `_entry_alloca(_clib_c_type(name), "clib.vt.{name}.{n}")` so storage
  lives for program lifetime when constructed from `with entry`
- Return pointer bitcast to Jac struct type; field 0 aligns with C struct start

Future: module-level `glob` vtables as true `.data` static globals (stable address
across calls, required if vtables outlive entry block).

### 4. C→Jac trampolines

**File:** `na_ir_gen_pass.impl/clib_vtable.impl.jac` (new)

When storing a Jac `def` into a vtable fn-ptr field:

1. `_emit_clib_c_trampoline(jac_fn, c_fn_ty)` — LLVM function with **C signature**
   `c_fn_ty`, body calls `jac_fn` with `_coerce_type` on each arg
2. Store trampoline address in struct field (not raw Jac fn address)
3. Cache in `clib_trampoline_funcs: dict[str, ir.Function]`
4. `int 0` → `inttoptr(0, fn_ptr_ty)` for NULL slots

Naming: `{jac_fn.name}.__clibcb.{n}` — grep for `__clibcb` in LLVM IR tests.

### 5. Flat struct layout for CEF vtables

Declare **flat** clib structs (all `cef_base_ref_counted_t` fields inlined), not
nested `obj CefBase`:

```jac
import from cef {
    obj cef_life_span_handler_t {
        has size: int = 0,
            add_ref: int = 0,
            release: int = 0,
            has_one_ref: int = 0,
            has_at_least_one_ref: int = 0,
            on_before_popup: int = 0,
            # ... remaining slots ...
            on_before_close: Callable[[int, int], None] = 0;
    }
}
```

Verified CEF 119 sizes (Linux x86_64, from prior header analysis):

| Struct | Size (bytes) |
|--------|----------------|
| `cef_base_ref_counted_t` | 40 |
| `cef_life_span_handler_t` | 88 |
| `cef_client_t` | 192 |
| `cef_app_t` | 80 |

`size` field must equal `sizeof(struct)` or CEF rejects init.

---

## Spike implementation inventory (reverted)

These changes were prototyped then **reverted** from the compiler tree. Re-apply
on a dedicated compiler branch when implementing J2.

| File | Change |
|------|--------|
| `na_ir_gen_pass.jac` | `clib_vtable_structs`, `clib_trampoline_funcs`, `_clib_vtable_counter`; method decls |
| `na_ir_gen_pass.impl/clib_vtable.impl.jac` | **New** — detect, alloc, coerce, trampoline (~110 lines) |
| `core.impl.jac` | `_clib_detect_vtable_structs()` after clib pass 1.5 |
| `objects.impl.jac` | Vtable branch in `_codegen_instantiation`; trampoline on fn-ptr fields; skip RC retain |
| `type_evaluator.impl.jac` | `int` → `Callable` in native |

Full spike source for `clib_vtable.impl.jac` is preserved in git history of this
conversation / can be recreated from the sections above.

---

## Test plan (not yet written)

### Compiler fixture: `clib_vtable_life_span.na.jac`

Location: `jac/tests/compiler/passes/native/fixtures/clib_vtable_life_span.na.jac`

```jac
"""Prototype: flat clib vtable with Callable slots (cef_life_span_handler_t shape)."""

import from "/usr/lib/libm.so.6" {
    obj LifeSpanHandler {
        has size: int = 0,
            add_ref: Callable[[int], None] = 0,
            release: Callable[[int], int] = 0,
            has_one_ref: Callable[[int], int] = 0,
            has_at_least_one_ref: Callable[[int], int] = 0,
            on_after_created: Callable[[int, int], None] = 0,
            on_before_close: Callable[[int, int], None] = 0;
    }
}

glob g_called: int = 0;

def _on_before_close(self: int, browser: int) -> None {
    g_called = 1;
}

def build_and_invoke() -> int {
    h = LifeSpanHandler(size=56, on_before_close=_on_before_close);
    h.on_before_close(h, 0);
    return g_called;
}
```

### Tests in `test_native_gen_pass.jac`

1. **Compile-only:** fixture compiles without E1001 on `Callable = 0` defaults
2. **LLVM IR:** module contains `__clibcb` trampoline symbol
3. **JIT:** `build_and_invoke()` returns `1`
4. **Layout:** IR struct size for `LifeSpanHandler` matches expected byte count

### Integration (post-J2)

- Rewrite `cef.na.jac` to clib vtables (drop `cef_shim.c`)
- Runtime smoke: `cef_test_host.na.jac` + full `desktop-cef` build
- Verify `on_context_created` bootstrap injection in render process

---

## Implementation order (recommended)

1. Type checker: null fn ptr (`int` → `Callable`, native only)
2. `clib_vtable.impl.jac` + detection hook
3. `_codegen_instantiation` vtable allocation path
4. Trampoline emission + fixture tests
5. `cef_life_span_handler_t` against real `libcef.so` (manual)
6. Expand to `cef_client_t`, `cef_app_t`, render-process handler
7. Delete `cef_shim.c` + update `jac-desktop` pipeline

---

## Out of scope for J2

- **J3:** Replace libpython loopback with Jac `na` HTTP
- **Phase 6:** CEF scheme handler (`cef_resource_handler_t` — another vtable)
- Nested string structs (`cef_string_t` UTF-16) — separate marshalling work

---

## References

- [`PLAN.md`](PLAN.md) — Phase J2 summary
- [`jac-desktop/jac_desktop/native/cef/README.md`](jac-desktop/jac_desktop/native/cef/README.md) — current shim architecture
- [`jac-desktop/jac_desktop/native/cef/cef_shim.c`](jac-desktop/jac_desktop/native/cef/cef_shim.c) — what J2 replaces
- Prior analysis: pure Jac clib attempt blocked on Callable defaults (see agent
  transcript around CEF binding compile errors)

---

## Appendix A — Reverted spike: `clib_vtable.impl.jac` (full source)

Re-apply on compiler branch as `jac/jaclang/compiler/passes/native/na_ir_gen_pass.impl/clib_vtable.impl.jac`.

```jac
"""C callback vtable support for clib structs (Phase J2).

Enables flat clib structs with function-pointer fields — the shape required
by CEF vtables (cef_life_span_handler_t prototype). Jac callbacks assigned to
vtable slots are wrapped in C-ABI trampolines; instances are allocated as
entry-block static storage (no RC header) so the pointer C sees matches the
struct layout at field 0.
"""

"""Scan registered clib structs and mark those with fn-ptr fields as vtables."""
impl NaIRGenPass._clib_detect_vtable_structs -> None {
    for name in self.clib_struct_names {
        if self._clib_struct_has_fn_ptr(name) {
            self.clib_vtable_structs.add(name);
        }
    }
}

"""True when a clib struct has at least one function-pointer field."""
impl NaIRGenPass._clib_struct_has_fn_ptr(name: str) -> bool {
    ftypes = self.struct_field_types.get(name, {});
    for ftype in ftypes.values() {
        if (
            isinstance(ftype, ir.PointerType)
            and isinstance(ftype.pointee, ir.FunctionType)
        ) {
            return True;
        }
    }
    return False;
}

"""Allocate a clib vtable instance in the entry block (stable for program lifetime).

Uses the C-laid-out type from `_clib_c_type` and skips RC headers so a pointer
to field 0 is a valid C struct address.
"""
impl NaIRGenPass._clib_alloc_vtable(name: str) -> ir.Value {
    ct = self._clib_c_type(name);
    stype = self.struct_types[name];
    sptype = stype.as_pointer();
    self._clib_vtable_counter += 1;
    buf = self._entry_alloca(ct, f"clib.vt.{name}.{self._clib_vtable_counter}");
    return self.builder.bitcast(buf, sptype, name="clib.vt.ptr");
}

"""Coerce a Jac function (or fn pointer / null int) to a C fn-ptr for vtable slots."""
impl NaIRGenPass._clib_coerce_callback(
    val: ir.Value, c_fn_ty: ir.FunctionType
) -> ir.Value {
    c_ptr_ty = c_fn_ty.as_pointer();
    # Null sentinel (int 0) → NULL fn pointer.
    if isinstance(val.type, ir.IntType) {
        return self.builder.inttoptr(val, c_ptr_ty, name="clib.cb.null");
    }
    # Already a compatible fn pointer.
    if val.type == c_ptr_ty {
        return val;
    }
    # Named Jac def / function reference → emit a C-ABI trampoline.
    jac_fn: (ir.Function | None) = None;
    if isinstance(val.type, ir.FunctionType) {
        jac_fn = val;
    } elif (
        isinstance(val.type, ir.PointerType)
        and isinstance(val.type.pointee, ir.FunctionType)
    ) {
        if isinstance(val, ir.Function) {
            jac_fn = val;
        }
    }
    if jac_fn is not None {
        tramp = self._emit_clib_c_trampoline(jac_fn, c_fn_ty);
        return self.builder.bitcast(tramp, c_ptr_ty, name="clib.cb.tramp");
    }
    return self._coerce_type(val, c_ptr_ty);
}

"""Emit a C-callable wrapper around a Jac function for a clib vtable slot."""
impl NaIRGenPass._emit_clib_c_trampoline(
    jac_fn: ir.Function, c_fn_ty: ir.FunctionType
) -> ir.Function {
    key = f"{jac_fn.name}|{c_fn_ty.as_pointer()}";
    if key in self.clib_trampoline_funcs {
        return self.clib_trampoline_funcs[key];
    }
    wname = f"{jac_fn.name}.__clibcb.{len(self.clib_trampoline_funcs)}";
    wrapper = ir.Function(self.llvm_module, c_fn_ty, name=wname);
    entry = wrapper.append_basic_block("entry");
    saved = self._builder;
    self._builder = ir.IRBuilder(entry);
    jac_ty = jac_fn.function_type;
    call_args: list[ir.Value] = [];
    for i in range(len(jac_ty.args)) {
        if i < len(wrapper.args) {
            call_args.append(self._coerce_type(wrapper.args[i], jac_ty.args[i]));
        }
    }
    result = self.builder.call(jac_fn, call_args, name="clibcb.call");
    if isinstance(c_fn_ty.return_type, ir.VoidType) {
        self.builder.ret_void();
    } else {
        self.builder.ret(self._coerce_type(result, c_fn_ty.return_type));
    }
    self._builder = saved;
    self.clib_trampoline_funcs[key] = wrapper;
    return wrapper;
}
```

## Appendix B — Reverted diffs (other files)

### `na_ir_gen_pass.jac` — add to `NaIRGenPass` fields

```jac
clib_vtable_structs: set[str] = set(),
clib_trampoline_funcs: dict[str, ir.Function] = {},
_clib_vtable_counter: int = 0,
```

And method declarations: `_clib_detect_vtable_structs`, `_clib_struct_has_fn_ptr`,
`_clib_alloc_vtable`, `_clib_coerce_callback`, `_emit_clib_c_trampoline`.

### `core.impl.jac` — after clib struct pass 1.5

```jac
self._clib_detect_vtable_structs();
```

### `objects.impl.jac` — `_codegen_instantiation`

- Branch on `type_name in self.clib_vtable_structs` → `_clib_alloc_vtable` (skip RC)
- On fn-ptr field store → `_clib_coerce_callback`
- Skip `_emit_rc_retain` for vtable struct pointer fields

### `type_evaluator.impl.jac` — inside `dest_type is FunctionType` block

```jac
# Null function pointer: int 0 → Callable in native clib vtable fields.
if isinstance(src_type, types.ClassType)
and src_type.is_builtin("int")
and self._in_native_context() {
    return True;
}
```

