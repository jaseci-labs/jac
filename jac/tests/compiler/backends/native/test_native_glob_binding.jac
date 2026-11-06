"""An imported global resolves to the module the importer names.

Two modules both define a global TABLE; the importer takes TABLE from the
second, and FIRST from the first through a module that only re-exports it.
Native lowering must bind TABLE to the module named in its import under every
module walk order and still find a re-exported global at the module that
defines it.
"""

import ctypes;
import os;
import from pathlib { Path }
import from tests.support { get_func, remember_native_unit }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = str(
         Path(__file__).resolve().parent / "fixtures" / "glob_binding" / "main.jac"
     );

"""The JIT engine of `path` compiled natively, module walk order `walk_order`."""
def jit_engine(path: str, walk_order: str | None = None) -> any {
    prog = JacProgram();
    opts = CompileOptions(
        force_codespace='native', native_module_walk_order=walk_order
    );
    mod = prog.compile(file_path=path, options=opts);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    eng = mod.gen.native_engine;
    assert eng is not None , "No JIT engine produced";
    remember_native_unit(eng, mod);
    return eng;
}

test "an imported global binds to the module its import names" {
    for order in [None, "reverse", "shuffle:7"] {
        got = get_func(jit_engine(FIXTURE, order), "table_size", ctypes.c_int64)();
        assert got == 6 , (
            f"{order}: table_size() == {got}; TABLE must be second_table's three "
            f"elements and FIRST the re-exported 1"
        );
    }
}

test "a Final scalar glob another module defines reads its value in importers" {
    import tempfile;
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "sizes.jac").write_text(
            "glob HEADER_SIZE: Final[i64] = 16,\n     MASK: Final[u64] = 18446744073709551612;\n"
        );
        main = Path(directory) / "reader.jac";
        main.write_text(
            """import from sizes { HEADER_SIZE, MASK }
def payload(address: i64) -> i64 {
    return address - HEADER_SIZE;
}
def masked(bits: u64) -> u64 {
    return bits & MASK;
}
with entry {
    print(payload(48), masked(u64(7)));
}
"""
        );
        eng = jit_engine(str(main));
        payload = get_func(eng, "payload", ctypes.c_int64, ctypes.c_int64);
        masked = get_func(eng, "masked", ctypes.c_uint64, ctypes.c_uint64);
        assert payload(48) == 32 , payload(48);
        assert masked(7) == 4 , masked(7);
    }
}

test "a Final glob of a module with a platform variant reads the variant's value" {
    import tempfile;
    import from jaclang.compiler.frontend.codeinfo {
        native_target_arch,
        native_target_os
    }
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "offsets.jac").write_text(
            "glob STATE_OFFSET: Final[i64] = 0;\n"
        );
        suffix = f"{native_target_os()}.{native_target_arch()}";
        (Path(directory) / f"offsets.{suffix}.jac").write_text(
            "glob STATE_OFFSET: Final[i64] = 11864;\n"
        );
        main = Path(directory) / "reader.jac";
        main.write_text(
            """import from offsets { STATE_OFFSET }
def state_of(base: i64) -> i64 {
    return base + STATE_OFFSET;
}
with entry {
    print(state_of(8));
}
"""
        );
        eng = jit_engine(str(main));
        state_of = get_func(eng, "state_of", ctypes.c_int64, ctypes.c_int64);
        assert state_of(8) == 11872 , (
            f"state_of(8) == {state_of(8)}; the platform variant's 11864 must win"
        );
    }
}

test "a global imported under an alias reads the exporting module's value" {
    import tempfile;
    import from tests.support { assert_native_identity }
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "flags.jac").write_text(
            "glob FLAG: i64 = 524288,\n     OTHER: i64 = 7;\n"
        );
        (Path(directory) / "core.jac").write_text(
            """import from flags { FLAG as FLAG_VALUE, OTHER as OTHER_VALUE }
glob FLAG: i32 = i32(FLAG_VALUE),
     RENAMED: i32 = i32(OTHER_VALUE);
def flag_now -> i64 {
    return FLAG_VALUE;
}
"""
        );
        main = Path(directory) / "reader.jac";
        main.write_text(
            """import from core { FLAG, RENAMED, flag_now }
with entry {
    print(FLAG, RENAMED, flag_now());
}
"""
        );
        out = assert_native_identity(str(main));
    }
    assert out.split() == ["524288", "7", "524288"] , out;
}
