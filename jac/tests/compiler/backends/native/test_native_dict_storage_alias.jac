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
