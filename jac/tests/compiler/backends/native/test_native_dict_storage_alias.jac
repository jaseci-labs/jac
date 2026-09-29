"""A bool-valued dict must not lend its storage to an int- or enum-valued one.

`_dict_val_spec` names a dict's helper set and struct type from the lowered
value type. It used to spell every non-pointer integer "i64", so the first
`dict[str, bool]` literal in a unit registered helpers under `ptr:i64` with a
1-bit value slot, and every later `dict[str, int]` / `dict[str, SomeEnum]`
literal adopted them: ordinals and ints were stored through `i1` and read
back as their low bit. The sealed `unitree` unit hit this the moment
`codeinfo`'s `dict[str, bool]` fields joined its closure ahead of
`Archetype.postinit`'s `{keyword: SymbolType}` table, and every `node`
became `SymbolType.MODULE` in the kit (E1096/E1097/E1114 on every OSP
program). Red-first: the fixture emits a bool dict, then an enum dict and
an int dict, and reads the members back.
"""
import from tests.support { unit_symbol }

import os;
import ctypes;
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { TESTS_DIR, native_address, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "a bool-valued dict does not alias an int or enum-valued dict's storage" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "dict_bool_int_alias.jac"),
        options=native_force_opts()
    );
    errs = [str(e) for e in prog.errors_had];
    assert not errs , f"errors: {errs}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine";
    addr = native_address(eng, "probe");
    assert addr != 0 , "probe not in JIT engine";
    fn = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
    got = [fn(i) for i in range(4)];
    assert got == [606, 707, 811, 1111] , (
        f"got {got}: kind_code*100 + ints. A low-bit pattern (0/1 in either "
        "half) means the enum or int dict adopted the bool dict's i1 slot"
    );
    llvm_text = str(ir.gen.llvm_ir);
    assert "__dict_set_ptr_i1" in llvm_text , (
        "the bool dict must get its own i1 helper set (__dict_*_ptr_i1); "
        "sharing ptr_i64 with the int and enum dicts is the aliasing bug"
    );
    assert "__dict_set_ptr_i64" in llvm_text , "the int/enum dicts keep i64 helpers";
}


test "dictionary values preserve nested set layouts during iteration" {
    prog = JacProgram();
    module = prog.compile(
        file_path=os.path.join(FIXTURES, "dictionary_value_sets.jac"),
        use_str="""
def probe -> int {
    groups: dict[str, set[str]] = {
        "first": {"one", "two"}, "second": {"two", "three"}
    };
    combined: set[str] = set();
    for names in groups.values() { combined = combined | names; }
    return len(combined) * 100 + int("one" in combined) * 10
        + int("three" in combined);
}
""",
        options=native_force_opts()
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    import from jaclang.compiler.backends.native.lowering { native_lowering_issues }
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    engine = module.gen.native_engine;
    assert engine is not None;
    probe = ctypes.CFUNCTYPE(ctypes.c_int64)(
        engine.get_function_address(unit_symbol(module, "probe"))
    );
    assert probe() == 311;
}


test "object hash layouts stay distinct from strings and other object classes" {
    import from tests.support { compile_native, get_func }
    import from jaclang.compiler.backends.native.lowering { native_lowering_issues }
    (engine, module) = compile_native("object_hash_layouts.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    probe = get_func(engine, "probe", ctypes.c_int64);
    assert probe() == 157;
}
