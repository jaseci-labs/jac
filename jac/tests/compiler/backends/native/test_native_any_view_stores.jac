"""A typed container read back as `list[any]` or `dict[str, any]` stays typed.

Writing through that view must store each value in the container's own
element representation; storing the boxed `any` corrupted the element
(the kernel's JCIR CgNode.push on a test block's decorator_list)."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

glob FIXTURE = os.path.join(NATIVE_FIXTURES, "any_view_stores");

def run(name: str) -> int {
    (eng, _) = compile_native("main.jac", FIXTURE);
    return get_func(eng, name, ctypes.c_int64)();
}

test "a push through a list[any] view of a typed list stores the element" {
    assert run("chk_push_into_typed_slot") == 414;
}

test "item set, insert and extend through a list[any] view store elements" {
    assert run("chk_set_insert_extend") == 4414;
}

test "scalars stored through a list[any] view of a list[int] stay ints" {
    assert run("chk_ints_through_any") == 6;
}

test "a store through a dict[str, any] view of a typed dict keeps the value" {
    assert run("chk_dict_through_any") == 2202;
}
