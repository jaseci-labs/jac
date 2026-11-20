"""Native lowering of optional-enum (`<enum> | None`) return types.

A function declared `-> Color | None` lowers its return value through the one
JacOptional rule: a tagged {i8, i64} value whose payload is the enum ordinal,
reported to the marshal layout as `opt.i64` with the enum name carried so the
marshaller maps a present ordinal back to a `Color` member and a None tag to
`None`. The AST-fallback type resolver used to walk the union's operands and
resolve the bare `None` to `void`, collapsing the whole return type to `void`;
any caller then failed to bind the result (`c = pick(...)`).
"""

import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "optional enum return lowers to a tagged optional ordinal" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "optional_enum_return.jac"),
        options=native_force_opts()
    );
    # Previously the `Color | None` return collapsed to `void`, so a caller
    # binding `c = pick(flag)` raised an E5090 void-binding diagnostic.
    assert not prog.errors_had , (
        f"unexpected diagnostics: {[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "no native layout";
    pick = layout.functions.get("pick");
    assert pick is not None , f"pick not lowered: {list(layout.functions)}";
    assert pick.ret_type == "opt.i64" , (
        f"optional enum return should lower to opt.i64, got {pick.ret_type!r}"
    );
    assert pick.ret_enum_type == "Color" , (
        f"enum-marshalling hint missing, got {pick.ret_enum_type!r}"
    );
}
