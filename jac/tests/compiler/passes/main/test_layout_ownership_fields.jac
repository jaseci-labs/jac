"""Ownership qualifiers on obj fields are layout-transparent."""

import os;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "nogc_infer"
     );

test "own str obj fields draw no W5032 layout warning" {
    path = os.path.join(FIXTURES, "own_str_fields.jac");
    prog = JacProgram();
    prog.compile(
        file_path=path, options=CompileOptions(aot_mode=True, type_check=True)
    );
    codes = [
        w.code.code
        for w in prog.warnings_had
        if w.code is not None
    ];
    assert "W5032" not in codes , f"layout warning on ownership-qualified field: {codes}";
}
