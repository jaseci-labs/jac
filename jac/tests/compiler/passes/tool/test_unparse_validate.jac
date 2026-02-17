"""Unparse validation tests – migrated from test_unparse_validate.py.

Tests that Jac files can be unparsed and re-parsed to produce identical
Python ASTs (round-trip validation).
"""

import ast as ast3;
import os;
import from difflib { unified_diff }
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.runtimelib.test { parametrize }
import from tests.fixtures_list { MICRO_JAC_FILES }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     EXAMPLES = os.path.join(JAC_ROOT, "examples");

test "double unparse" {
    code_gen_pure = JacProgram().compile(
        os.path.join(EXAMPLES, "manual_code", "circle.jac")
    );
    x = code_gen_pure.unparse();
    y = code_gen_pure.unparse();
    assert x == y , "Double unparse produced different results:\n" + "\n".join(
        unified_diff(x.splitlines(), y.splitlines())
    );
}

def unparse_roundtrip_test(rel_path: str) -> None {
    filename = os.path.normpath(os.path.join(JAC_ROOT, rel_path));
    if not os.path.exists(filename) {
        return;
    }
    code_gen_pure = JacProgram().compile(filename);
    if code_gen_pure is None or code_gen_pure.gen.py_ast is None {
        return;
    }
    before = ast3.dump(code_gen_pure.gen.py_ast[0], indent=2);
    x = code_gen_pure.unparse();
    code_gen_jac = JacProgram().compile(use_str=x, file_path=filename);
    assert code_gen_jac is not None and code_gen_jac.gen.py_ast is not None , f"Re-compilation failed for {filename}";
    after = ast3.dump(code_gen_jac.gen.py_ast[0], indent=2);
    if "circle_clean_tests.jac" in filename {
        diff_lines = [
            i
            for i in unified_diff(before.splitlines(), after.splitlines(), n=0)
            if "test" not in i
        ];
        assert len(diff_lines) == 5 , f"circle_clean_tests.jac: expected 5 diff lines, got {len(
            diff_lines
        )}";
    } else {
        diff = "\n".join(unified_diff(before.splitlines(), after.splitlines()));
        assert len(diff) == 0 , f"Round-trip diff for {filename}:\n{diff[:500]}";
    }
}

with entry {
    parametrize(
        "unparse roundtrip",
        MICRO_JAC_FILES,
        unparse_roundtrip_test,
        id_fn=lambda f : Path(f).stem
    );
}
