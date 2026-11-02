"""`and`/`or` over operands of different native types return an operand.

When one side was a boxed union and the other a plain object, the two did
not unify, so the expression fell back to the truth value: `g.es or fallback`
became `True`, and casting it back to an object dereferenced address 1.
Operands of different types now meet as a boxed value.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "`or` and `and` over a union and an object return an operand" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "bool_expr_union_operand.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[:2] == ["held fallback", "fallback none"] , out;
}
