"""The native import link releases each dep's memory once its cache lands.

`_compile_and_link_native_imports` used to keep every freshly compiled
dependency's LLVM module and unitree alive for the whole link loop, so a
many-module build held all of them simultaneously. Once a dep's ir_cache
and ir_meta files are written, its contribution to the link lives in the
IR string and on disk: the LLVM module is closed and the compiled unit
evicted from the program. Later verdict lookups for an evicted dep are
answered by the ir_meta `demoted_symbols` fallback in
`native_unit_demotions`, which exists precisely for deps that are no
longer in memory.
"""

import ctypes;
import os;

import from tests.support { TESTS_DIR, get_func, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Remove the dep's cached IR so the compile branch (the one that
releases memory) is the one that runs."""
def scrub_dep_cache -> None {
    import from jaclang.compiler.driver.jir { get_native_cache_dir }
    dep = os.path.realpath(os.path.join(FIXTURES, "memrelease_dep.jac"));
    cache_dir = str(get_native_cache_dir(dep));
    if not os.path.isdir(cache_dir) {
        return;
    }
    for fn in os.listdir(cache_dir) {
        if fn.startswith("memrelease_dep.")
            and (fn.endswith(".ir_cache") or fn.endswith(".ir_meta")) {
            try {
                os.remove(os.path.join(cache_dir, fn));
            } except OSError {}
        }
    }
}

def compile_main -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "memrelease_main.jac"),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"compile errors: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine produced";
    return (prog, eng, ir);
}

test "link releases the dep's IR and unit after its cache lands" {
    scrub_dep_cache();
    (prog, eng, _) = compile_main();
    f = get_func(eng, "mr_use", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 22;
    dep = os.path.realpath(os.path.join(FIXTURES, "memrelease_dep.jac"));
    found = prog.find_module(dep);
    assert found is None or found.gen.llvm_ir is None , (
        "the linked dep must not keep a live LLVM module in memory"
    );
}

test "a later build serves the released dep from its cache" {
    (prog, eng, _) = compile_main();
    f = get_func(eng, "mr_use", ctypes.c_int64, ctypes.c_int64);
    assert f(9) == 28;
}
