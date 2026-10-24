"""An importer declares the imported functions it names, and no others.

A unit whose import reaches a module of many functions declares only the
functions its code calls: by bare name, by module-qualified name, or from a
nested function. Importing a name without calling it declares nothing."""
import ctypes;
import re;
import from tests.support { compile_native, compile_native_ir, get_func }

def _declared_wide(ir_text: str) -> set[str] {
    return set(
        re.findall(r"^declare[^@\n]*@\"?[^\"(\n]*\b(wide_\d+)\"?\(", ir_text, re.M)
    );
}

test "a unit declares only the imported functions it calls" {
    module = compile_native_ir("lazy_decl_user.jac");
    declared = _declared_wide(str(module.gen.llvm_ir));
    assert declared == {"wide_3", "wide_7", "wide_19"} , sorted(declared);
}

test "imported functions declared on first reference still call correctly" {
    (engine, _) = compile_native("lazy_decl_user.jac");
    assert get_func(engine, "used_bare", ctypes.c_int64, ctypes.c_int64)(2) == 38;
    assert get_func(engine, "used_qualified", ctypes.c_int64, ctypes.c_int64)(1) == 40;
    assert get_func(engine, "nested_use", ctypes.c_int64, ctypes.c_int64)(1) == 17;
}

test "an import declared after a local function of its name leaves the local's return facts" {
    module = compile_native_ir("lazy_ret_user.jac");
    layout = module.gen.native_layout;
    assert layout is not None;
    local = layout.functions.get("items");
    assert local is not None and local.ret_elem_keys == ["int"] , local;
}
