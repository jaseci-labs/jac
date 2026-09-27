"""A static method called through an instance receives no receiver.

Lowering `self.key_of(path)` for a static `key_of` took the instance-method
path, which prepends the receiver: the static method read the object as its
first parameter, so `JacProgram.hub_key` in the kernel resolved the program
object's bytes as a path. The call now drops the receiver when the resolved
method is static, and skips the null check and vtable dispatch it only needs
for instance methods.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "a static method called through a receiver gets only its own arguments" {
    (eng, _ir) = compile_native("static_via_receiver.jac");
    assert get_func(eng, "static_through_class_receiver", ctypes.c_int64)() == 1;
    assert get_func(eng, "static_through_obj_receiver", ctypes.c_int64)() == 47;
}
