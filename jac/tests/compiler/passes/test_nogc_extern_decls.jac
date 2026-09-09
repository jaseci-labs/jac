"""Regression tests for the nogc fence vs clib extern declarations.

The E1401/E1404 param sweep used to treat every parameter of an
`import from lib { def ... }` extern block as an unannotated heap contract
position, and the native width types (i32/f32/u8/...) were missing from the
scalar set -- so a nogc-enforced module could not declare FFI at all (found
moving jaclang.org's shooter to an enforced `game/arena.jac`). Extern
decls are FFI contracts outside the ownership world: params under a
`uni.Import` parent are skipped, width types are scalars, and the fence
must still fire on regular defs.
"""

import os;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "nogc_extern"
     );

"""Compile a fixture as a headerless nogc-enforced module; return its unique,
sorted diagnostic codes."""
def enforced_codes(fixture: str) -> list[str] {
    path = os.path.join(FIXTURES, fixture);
    prog = JacProgram();
    opts = CompileOptions(aot_mode=True, memory_profile="nogc");
    prog.compile(file_path=path, options=opts);
    codes: set[str] = set();
    for alert in list(prog.errors_had) {
        if alert.code is not None {
            codes.add(alert.code.code);
        }
    }
    return sorted(codes);
}

test "clib extern decls with width and str params are exempt from the fence" {
    assert enforced_codes("clib_externs.jac") == [];
}

test "str param on a regular def still trips E1401" {
    assert enforced_codes("plain_str_param.jac") == ["E1401"];
}
