"""Native lowering of optional-enum (`<enum> | None`) return types.

A function declared `-> Color | None` must lower its return value to an i64
enum ordinal (with a sentinel for `None`) and carry the enum name so the
marshaller can map the ordinal back to a `Color` member -- identical to a plain
`-> Color` return. The AST-fallback type resolver used to walk the union's
operands and resolve the bare `None` to `void`, collapsing the whole return type
to `void`; any caller then failed to bind the result (`c = pick(...)`).
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

test "optional enum return lowers to i64 with an enum-marshalling hint" {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "optional_enum_return.na.jac"));
    # Previously the `Color | None` return collapsed to `void`, so a caller
    # binding `c = pick(flag)` raised an E5090 void-binding diagnostic.
    assert not prog.errors_had , (
        f"unexpected diagnostics: {[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "no native layout";
    pick = layout.functions.get("pick");
    assert pick is not None , f"pick not lowered: {list(layout.functions)}";
    assert pick.ret_type == "i64" , (
        f"optional enum return should lower to i64, got {pick.ret_type!r}"
    );
    assert pick.ret_enum_type == "Color" , (
        f"enum-marshalling hint missing, got {pick.ret_enum_type!r}"
    );
}
