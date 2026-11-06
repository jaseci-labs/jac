"""A container method or in-place operator reaches its container natively
through a field, an element or a narrowed optional."""
import ctypes;
import from tests.support { compile_native, get_func }

test "set |= updates a field's and an element's set in place" {
    (eng, _) = compile_native("container_receivers.jac");
    assert get_func(eng, "chk_field_union", ctypes.c_int64)() == 33;
    assert get_func(eng, "grow_element", ctypes.c_int64)() == 31;
}

test "a method on a narrowed optional dict runs on the dict" {
    (eng, _) = compile_native("container_receivers.jac");
    assert get_func(eng, "chk_narrowed_get", ctypes.c_int64)() == 54;
}
