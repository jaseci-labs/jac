"""Native lowering of optional-enum (`<enum> | None`) return types.

A function declared `-> Color | None` lowers its return value through the one
JacOptional rule: a tagged value whose payload is the enum ordinal, exported
with the enum carried in its type so the marshaller maps a present ordinal back
to a `Color` member and a None tag to `None`. The AST-fallback type resolver used to walk the union's operands and
resolve the bare `None` to `void`, collapsing the whole return type to `void`;
any caller then failed to bind the result (`c = pick(...)`).
"""

import from tests.support { compile_native_ir, source_spelled }

test "optional enum return lowers to a tagged optional ordinal" {
    fx = compile_native_ir("optional_enum_return.jac");
    # Previously the `Color | None` return collapsed to `void`, so a caller
    # binding `c = pick(flag)` could not lower.
    assert not fx.is_demoted("pick") , fx.reason("pick");
    assert not fx.is_demoted("use_pick") , fx.reason("use_pick");
    pick = fx.iface().exports.get("pick");
    assert pick is not None , f"pick not exported: {list(fx.iface().exports)}";
    ret = source_spelled(pick.ret_type);
    assert ret.startswith("opt") and "Color" in ret , (
        f"optional enum return should lower to an optional Color, got {ret!r}"
    );
}
