"""The native decompressor accepts mutable buffers without changing the input."""
import ctypes;
import from tests.support { compile_native, get_func }

test "native zlib decompression accepts bytes and bytearray" {
    (engine, _) = compile_native("zlib_bytearray.jac");
    cases = get_func(engine, "buffer_case", ctypes.c_int64, ctypes.c_int64);
    observed = [cases(i) for i in range(4)];
    assert observed == [2, 1, 2, 1] , str(observed);
    any_check = get_func(engine, "any_buffer_checks", ctypes.c_bool);
    assert any_check();
    check = get_func(engine, "bytearray_checks", ctypes.c_bool);
    assert check();
}
