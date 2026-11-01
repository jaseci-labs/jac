"""A borrowed walk over a managed chain answers the same, with no refcounting.

`head: &memo | None = &p.tokens[p.mark].memo_head` borrows a path the
checker proved stable, so the slot holds no reference: the walk emits no
retain and no release, while the same walk written without the annotation
pays both per step unless borrow inference proves it a borrow too, which it
does for this walk.
"""

import ctypes;
import re;
import from jaclang.compiler.backends.native.mir.emit {
    RELEASE_ACYCLIC_SYMBOL,
    RELEASE_SYMBOL,
    RETAIN_SYMBOL
}
import from tests.support {
    compile_native,
    compile_native_ir,
    native_address,
    native_force_opts,
    unit_symbol
}

glob RETAIN_CALL: str = r"@\"?" + re.escape(RETAIN_SYMBOL) + r"\"?\(",
     RELEASE_CALL: str = r"@\"?("
         + re.escape(RELEASE_SYMBOL)
         + "|"
         + re.escape(RELEASE_ACYCLIC_SYMBOL)
         + r")\"?\(";

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
        address = native_address(eng, name);
        assert isinstance(address, int) and address != 0 , name;
        walk = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address);
        for (rule_type, want) in [(1, 11), (2, 22), (3, 33), (9, -1)] {
            got = walk(rule_type);
            assert got == want , f"{name}({rule_type}): {got} != {want}";
        }
    }
}

test "the borrowed walk emits no retain and no release" {
    # (with borrow inference off, so that the unannotated walk is the
    # counted control)
    opts = native_force_opts();
    opts.na_borrow_infer = False;
    fx = compile_native_ir("managed_borrow_walk.jac", options=opts);
    ir = fx.llvm_ir();
    borrowed = function_body(ir, re.escape(unit_symbol(fx, "borrowed_walk")));
    owning = function_body(ir, re.escape(unit_symbol(fx, "owning_walk")));
    assert not re.findall(RETAIN_CALL, borrowed) , (
        "the borrowed walk still retains: " + borrowed
    );
    assert not re.findall(RELEASE_CALL, borrowed) , (
        "the borrowed walk still releases: " + borrowed
    );
    assert re.findall(RETAIN_CALL, owning) , (
        "the owning walk is expected to retain, so this test would prove nothing"
    );
}

test "borrow inference makes the unannotated walk a borrow as well" {
    fx = compile_native_ir("managed_borrow_walk.jac");
    owning = function_body(fx.llvm_ir(), re.escape(unit_symbol(fx, "owning_walk")));
    assert not re.findall(RETAIN_CALL, owning) , (
        "the unannotated walk still retains: " + owning
    );
}
