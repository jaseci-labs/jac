"""C→Jac callback trampolines for clib vtable structs (issue #6570).

C libraries with callback-based APIs (CEF, libuv) describe their hooks as
vtable structs: plain C structs whose fields are function pointers. A Jac
`def` stored into such a slot is later called BY THE C RUNTIME with the C
signature from the slot's `Callable[[...], ret]` annotation — which need
not match the Jac function's native signature (Jac `int` params are i64;
a slot may declare i32, f64, ...). Each such store goes through a thin
LLVM wrapper carrying the exact C function type that coerces every
argument to the Jac parameter type, calls the Jac function, and coerces
the result back. Trampolines are cached per (jac_fn, c_fn_type) pair and
named `{jac_fn}.__clibcb.{n}` so IR tests can grep for `__clibcb`.
"""

"""True when a registered clib struct has a function-pointer field."""
impl NaIRGenPass._clib_struct_has_fn_ptr(name: str) -> bool {
    for ftype in self.struct_field_types.get(name, {}).values() {
        if isinstance(ftype, ir.PointerType)
        and isinstance(ftype.pointee, ir.FunctionType) {
            return True;
        }
    }
    return False;
}

"""Record which clib structs are vtables (have fn-ptr slots).

Runs per import block, after pass 1.5 has laid out the struct bodies,
so every field's LLVM type is final.
"""
impl NaIRGenPass._clib_detect_vtable_structs -> None {
    for name in self.clib_struct_names {
        if name not in self.clib_vtable_structs
        and self._clib_struct_has_fn_ptr(name) {
            self.clib_vtable_structs.add(name);
        }
    }
}

"""Coerce a value stored into a clib vtable fn-ptr slot to the slot's C type.

A Jac `def` whose native signature already matches the slot is stored
directly; one with a different signature goes through a C-ABI trampoline.
Anything else (the `= 0` NULL default, raw integers, loaded pointers)
falls through to the generic coercions — int → inttoptr yields the C
NULL function pointer for the literal 0.
"""
impl NaIRGenPass._clib_coerce_callback(val: ir.Value, c_fn_ty: ir.Type) -> ir.Value {
    if isinstance(val, ir.Function) {
        if val.function_type == c_fn_ty.pointee {
            return self.builder.bitcast(val, c_fn_ty, name="clibcb.direct");
        }
        tramp = self._emit_clib_c_trampoline(val, c_fn_ty);
        return self.builder.bitcast(tramp, c_fn_ty, name="clibcb.tramp");
    }
    return self._coerce_type(val, c_fn_ty);
}

"""Integer-aware argument coercion for trampoline boundaries.

C integer arguments are signed by default, so width changes between the
C slot type and the Jac parameter type must sign-extend / truncate —
unlike `_coerce_type`, whose zext is tuned for bools. Everything
non-integer delegates to the generic coercions.
"""
impl NaIRGenPass._clib_cb_coerce_scalar(
    val: ir.Value, target_type: ir.Type
) -> ir.Value {
    if val.type == target_type {
        return val;
    }
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.IntType) {
        if val.type.width < target_type.width {
            return self.builder.sext(val, target_type, name="clibcb.sext");
        }
        return self.builder.trunc(val, target_type, name="clibcb.trunc");
    }
    return self._coerce_type(val, target_type);
}

"""Emit (or fetch from cache) the C-ABI trampoline for `jac_fn`.

The trampoline is an internal function with the slot's exact C function
type. C argument counts may differ from the Jac signature (CEF passes
`self` first, a Jac handler may ignore trailing params): extra C args are
dropped, missing Jac args are zero/null-filled, so the indirect call from
C stays well-typed either way.
"""
impl NaIRGenPass._emit_clib_c_trampoline(
    jac_fn: ir.Function, c_fn_ty: ir.Type
) -> ir.Function {
    key = f"{jac_fn.name}|{c_fn_ty}";
    cached = self.clib_trampoline_funcs.get(key);
    if cached is not None {
        return cached;
    }
    n = len(self.clib_trampoline_funcs);
    tramp = ir.Function(
        self.llvm_module, c_fn_ty.pointee, name=f"{jac_fn.name}.__clibcb.{n}"
    );
    tramp.linkage = "internal";
    entry = tramp.append_basic_block("entry");
    saved_builder = self._builder;
    self._builder = ir.IRBuilder(entry);
    jac_params = jac_fn.function_type.args;
    call_args: list[ir.Value] = [];
    for (i, arg) in enumerate(tramp.args) {
        arg.name = f"c.arg{i}";
        if i < len(jac_params) {
            call_args.append(self._clib_cb_coerce_scalar(arg, jac_params[i]));
        }
    }
    while len(call_args) < len(jac_params) {
        pty = jac_params[len(call_args)];
        if isinstance(pty, ir.PointerType) {
            call_args.append(ir.Constant(pty, None));
        } else {
            call_args.append(ir.Constant(pty, 0));
        }
    }
    result = self.builder.call(jac_fn, call_args, name="clibcb.call");
    c_ret = c_fn_ty.pointee.return_type;
    if isinstance(c_ret, ir.VoidType) {
        self.builder.ret_void();
    } elif isinstance(jac_fn.function_type.return_type, ir.VoidType) {
        if isinstance(c_ret, ir.PointerType) {
            self.builder.ret(ir.Constant(c_ret, None));
        } else {
            self.builder.ret(ir.Constant(c_ret, 0));
        }
    } else {
        self.builder.ret(self._clib_cb_coerce_scalar(result, c_ret));
    }
    self._builder = saved_builder;
    self.clib_trampoline_funcs[key] = tramp;
    return tramp;
}

"""Allocate a clib vtable struct as plain C memory (issue #6571).

C vtable structs are read by the C runtime starting at field 0 (CEF
validates `struct->size` there) and live as long as the C side holds
them, so the instance must be flat C data: no RC header at negative
offsets, no destructor, no type tag, and a lifetime Jac never reclaims.
`calloc` gives a zero-initialized block (unset fn-ptr slots are NULL C
function pointers) on the heap, so the address stays valid after the
creating function returns — vtables registered with `cef_initialize()`
&co. are invoked long after the registering scope is gone. Ownership
belongs to the C library (CEF vtables embed their own ref-counting via
`cef_base_ref_counted_t`); Jac intentionally never frees the block.

The allocation uses the C-laid-out type from `_clib_c_type` so nested
clib structs reserve their inlined (by-value) size, then views the block
through the Jac struct type for field access.
"""
impl NaIRGenPass._clib_alloc_vtable(name: str) -> ir.Value {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    calloc_fn = self._get_or_declare_extern("calloc", i8_ptr, [i64, i64]);
    ct = self._clib_c_type(name);
    null_ptr = ir.Constant(ct.as_pointer(), None);
    size_gep = self.builder.gep(
        null_ptr, [ir.Constant(ir.IntType(32), 1)], name="clib.vt.sizeof.gep"
    );
    size = self.builder.ptrtoint(size_gep, i64, name="clib.vt.sizeof");
    raw = self.builder.call(calloc_fn, [ir.Constant(i64, 1), size], name="clib.vt.raw");
    return self.builder.bitcast(
        raw, self.struct_types[name].as_pointer(), name="clib.vt.ptr"
    );
}
