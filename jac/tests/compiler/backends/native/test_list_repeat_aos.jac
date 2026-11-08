"""list *= n stays correct at the AoS growth boundary (#10394).

Under enforced headerless codegen, `list[own Cell]` lowers to a by-value
buffer whose get() returns an interior pointer. A naive repeat loop feeds
that pointer to push(), which frees the buffer mid-iteration when capacity
eight is exceeded. The existing native test harness compiles this fixture
in-process with the nogc ownership profile and checks the boundary cases.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, get_func, remember_native_unit }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "nogc",
         "list_repeat_aos.jac"
     );

test "list[own Cell] *= n grows once, clears, and skips empty repeats" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            force_codespace="native", na_gc_mode="nogc", nogc_enforce_all=True
        )
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , "No native engine produced";
    remember_native_unit(eng, ir);

    repeat_cells = get_func(eng, "repeat_cells", ctypes.c_int64, ctypes.c_int64);
    clear_cells = get_func(eng, "clear_cells", ctypes.c_int64);
    reuse_after_clear = get_func(eng, "reuse_after_clear", ctypes.c_int64);
    repeat_empty = get_func(eng, "repeat_empty", ctypes.c_int64);
    self_extend_cells = get_func(eng, "self_extend_cells", ctypes.c_int64);
    overflow_repeat_raises = get_func(eng, "overflow_repeat_raises", ctypes.c_bool);
    extend_moves_source = get_func(eng, "extend_moves_source", ctypes.c_int64);
    repeat_zero_sized = get_func(eng, "repeat_zero_sized", ctypes.c_int64);
    self_extend_zero_sized = get_func(eng, "self_extend_zero_sized", ctypes.c_int64);

    assert repeat_cells(9) == 6399;
    assert clear_cells() == 0;
    assert reuse_after_clear() == 506;
    assert repeat_empty() == 0;
    assert self_extend_cells() == 3010;
    assert overflow_repeat_raises();
    assert extend_moves_source() == 6060;
    assert repeat_zero_sized() == 4;
    assert self_extend_zero_sized() == 18;
}
