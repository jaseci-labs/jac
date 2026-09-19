"""Native visit coercion must preserve the active IR block and list ownership.

Converting a pointer list to the boxed OSP list creates a copy loop and
consumes an owned source. Capture the call builder after that conversion,
and release the converted temporary rather than freeing the source twice.
"""

import ctypes;
import os;
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT, native_force_opts }

glob _ENGINE: list[any] = [];

def engine -> any {
    if _ENGINE {
        return _ENGINE[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(
            JAC_ROOT,
            "tests",
            "compiler",
            "backends",
            "native",
            "fixtures",
            "osp_visit_coercion.jac"
        ),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "visit coercion must compile natively";
    _ENGINE.append(eng);
    return eng;
}

def run_visits(name: str, repeats: int) -> int {
    address = engine().get_function_address(name);
    assert address != 0 , f"missing native function {name}";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address)(repeats);
}

test "indexed visit lists compile and survive repeated traversal" {
    assert run_visits("indexed_visits", 10000) == 30000;
}

test "visit coercion preserves borrowed lists and node fields" {
    assert run_visits("borrowed_visits", 10000) == 120014;
}
