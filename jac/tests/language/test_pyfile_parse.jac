"""Python file parsing tests -- migrated from test_pyfile_parse.py.

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
import from jaclang.runtimelib.test { parametrize }
import from tests.fixtures_list { JACLANG_PYTHON_FILES }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent);

def pyfile_parse_test(rel_path: str) {
    """Every in-repo Python file should parse and unparse cleanly."""
    filename = os.path.normpath(os.path.join(JAC_ROOT, rel_path));
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
    prog = JacProgram.jac_str_formatter(source_str=unparsed, file_path=filename);
    assert not prog.errors_had , (
        f"Failed to re-parse generated Jac for {filename}: {prog.errors_had}"
    );
}

with entry {
    parametrize(
        "python file parses with pyast build pass",
        JACLANG_PYTHON_FILES,
        pyfile_parse_test,
        id_fn=lambda f : Path(f).stem
    );
}
