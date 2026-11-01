"""Native visit coercion must preserve the active IR block and list ownership.

Converting a pointer list to the boxed OSP list creates a copy loop and
consumes an owned source. Capture the call builder after that conversion,
and release the converted temporary rather than freeing the source twice.
"""

import ctypes;
import from tests.support { compile_native, native_address }

glob _ENGINE: list[any] = [];

def engine -> any {
    if _ENGINE {
        return _ENGINE[0];
    }
    (eng, _) = compile_native("osp_visit_coercion.jac");
    _ENGINE.append(eng);
    return eng;
}

def run_visits(name: str, repeats: int) -> int {
    address = native_address(engine(), name);
    assert address != 0 , f"missing native function {name}";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address)(repeats);
}

test "indexed visit lists compile and survive repeated traversal" {
    assert run_visits("indexed_visits", 10000) == 30000;
}

test "visit coercion preserves borrowed lists and node fields" {
    assert run_visits("borrowed_visits", 10000) == 120014;
}
