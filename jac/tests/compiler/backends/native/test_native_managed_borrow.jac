"""A borrowed walk over a managed chain answers the same, with no refcounting.

`head: &memo | None = &p.tokens[p.mark].memo_head` borrows a path the
checker proved stable, so the slot holds no reference: the walk emits no
retain and no release, while the same walk written without the annotation
pays both per step.
"""

import ctypes;
import re;
import from tests.support { compile_native, compile_native_ir }

"""The body of `name` in `ir`, from its define line to its closing brace."""
def function_body(ir: str, name: str) -> str {
    found = re.search(
        r"^define[^\n]*@\"?" + name + r"\"?\([^\n]*\)[^{]*\{\n(.*?)^\}", ir, re.S | re.M
    );
    assert found is not None , f"{name} missing from the emitted IR";
    return found.group(1);
}

test "a borrowed walk answers what the owning walk answers" {
    (eng, _) = compile_native("managed_borrow_walk.jac");
    for name in ["borrowed", "owning"] {
        address = eng.get_function_address(name);
        assert isinstance(address, int) and address != 0 , name;
        walk = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address);
        for (rule_type, want) in [(1, 11), (2, 22), (3, 33), (9, -1)] {
            got = walk(rule_type);
            assert got == want , f"{name}({rule_type}): {got} != {want}";
        }
    }
}

test "the borrowed walk emits no retain and no release" {
    module = compile_native_ir("managed_borrow_walk.jac");
    ir = str(module.gen.llvm_ir);
    borrowed = function_body(ir, "borrowed_walk");
    owning = function_body(ir, "owning_walk");
    assert not re.findall(r"@\"?_*rc_retain", borrowed) , (
        "the borrowed walk still retains: " + borrowed
    );
    assert not re.findall(r"@\"?_*rc_release", borrowed) , (
        "the borrowed walk still releases: " + borrowed
    );
    assert re.findall(r"@\"?_*rc_retain", owning) , (
        "the owning walk is expected to retain, so this test would prove nothing"
    );
}
