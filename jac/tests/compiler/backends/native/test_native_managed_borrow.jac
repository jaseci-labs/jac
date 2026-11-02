"""A borrowed walk over a managed chain answers the same, with no refcounting.

`head: &memo | None = &p.tokens[p.mark].memo_head` borrows a path the
checker proved stable, so the slot holds no reference. The borrowed walk and
the same walk written without the annotation must answer alike.
"""

import ctypes;
import from tests.support { compile_native, native_address }

test "a borrowed walk answers what the owning walk answers" {
    (eng, _) = compile_native("managed_borrow_walk.jac");
    for name in ["borrowed", "owning"] {
        address = native_address(eng, name);
        assert isinstance(address, int) and address != 0 , name;
        walk = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address);
        for (rule_type, want) in [(1, 11), (2, 22), (3, 33), (9, -1)] {
            got = walk(rule_type);
            assert got == want , f"{name}({rule_type}): {got} != {want}";
        }
    }
}
