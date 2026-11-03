"""Ownership qualifiers on obj fields are layout-transparent."""

import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { JAC_ROOT, kernel_compile_file, warning_codes }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "nogc_infer"
     );

test "own str obj fields draw no W5032 layout warning" {
    path = os.path.join(FIXTURES, "own_str_fields.jac");
    codes = warning_codes(kernel_compile_file(path, CompileOptions(aot_mode=True)));
    assert "W5032" not in codes , f"layout warning on ownership-qualified field: {codes}";
}
