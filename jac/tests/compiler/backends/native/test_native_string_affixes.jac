"""String affixes share bounded comparison and tuple overload semantics."""
import ctypes;
import from tests.support { compile_native, native_str_func as get_sfunc }

test "string affixes support tuple candidates and bounds" {
    (eng, _) = compile_native("string_affixes.jac");
    suffix = get_sfunc(eng, "suffix", ctypes.c_int64, ctypes.c_char_p);
    prefix = get_sfunc(eng, "prefix", ctypes.c_int64, ctypes.c_char_p);
    bounds = get_sfunc(
        eng, "bounds", ctypes.c_int64, ctypes.c_char_p, ctypes.c_int64, ctypes.c_int64
    );
    empty = get_sfunc(eng, "empty", ctypes.c_int64, ctypes.c_char_p, ctypes.c_int64);
    long_suffix = get_sfunc(eng, "long_suffix", ctypes.c_int64, ctypes.c_char_p);
    for value in ["", "a.jac", "module.py", "stub.pyi", "a.p", "jaclang", "python"] {
        assert bool(suffix(value.encode())) == value.endswith((".jac", ".py", ".pyi"));
        assert bool(prefix(value.encode())) == value.startswith(("jac", "python"));
        assert not long_suffix(value.encode());
    }
    for start in [-20, -3, 0, 2, 6, 10] {
        for end in [-20, -1, 0, 5, 6, 10] {
            value = "xxjac!";
            assert bool(bounds(value.encode(), start, end))
                == value.endswith(("jac", "py"), start, end);
        }
        assert bool(empty(b"jac", start)) == "jac".endswith("", start);
    }
}
