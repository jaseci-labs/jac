"""Iterator adapters own returned references until replacement or destruction."""
import ctypes;
import from tests.support { compile_native, get_func }

test "iterator results release on exhaustion and early exit" {
    (engine, _) = compile_native("iterator_result_ownership.jac");
    check = get_func(engine, "check", ctypes.c_bool, ctypes.c_bool);
    for early in [False, True] {
        for _ in range(100) {
            assert check(early) , early;
        }
    }
}
