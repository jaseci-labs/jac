"""Python file parsing tests – migrated from test_pyfile_parse.py.

Ensures all Jaclang Python source files can be parsed via PyastBuildPass
and that the generated Jac code can be re-parsed by the Jac parser.
"""

import ast as py_ast;
import os;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as ast;
import from jaclang.compiler.passes.main { PyastBuildPass }
import from jaclang.jac0core.program { JacProgram }
import from tests.fixtures_list { JACLANG_PYTHON_FILES }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent);

test "python files parse with pyast build pass" {
    failures: list[str] = [];
    for rel_path in JACLANG_PYTHON_FILES {
        filename = os.path.normpath(os.path.join(JAC_ROOT, rel_path));
        if not os.path.exists(filename) {
            continue;
        }
        try {
            source = Path(filename).read_text();
            py_module = PyastBuildPass(
                ir_in=ast.PythonModuleAst(
                    py_ast.parse(source), orig_src=ast.Source(source, filename)
                ),
                prog=JacProgram()
            ).ir_out;

            assert isinstance(py_module, ast.Module);
            unparsed = py_module.unparse(requires_format=False);
            assert isinstance(unparsed, str);

            # Verify generated Jac can be re-parsed
            prog = JacProgram.jac_str_formatter(
                source_str=unparsed, file_path=filename
            );
            if prog.errors_had {
                failures.append(
                    f"Failed to re-parse generated Jac for {filename}: {prog.errors_had}"
                );
            }
        } except Exception as e {
            failures.append(f"Exception for {filename}: {e}");
        }
    }
    assert len(failures) == 0 , (
        f"{len(failures)} file(s) failed:\n" + "\n".join(failures[:20])
    );
}
