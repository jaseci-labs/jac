"""PyAST build pass tests – migrated from test_pyast_build_pass.py.

Tests that Python source files are correctly converted to Jac AST via
the PyastBuildPass, and that specific conversions (docstrings, f-strings)
are handled properly.
"""

import ast as py_ast;
import inspect;
import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main { PyastBuildPass }
import from jaclang.jac0core.helpers { pascal_to_snake }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.unitree { PythonModuleAst, Source }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent),
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures"
     );

test "synced to latest py ast" {
    unparser_cls = py_ast._Unparser;
    visit_methods = (
        [
            method
            for method in dir(unparser_cls)
            if method.startswith("visit_")
        ] + list(unparser_cls.binop.keys()) + list(unparser_cls.unop.keys()) + list(
            unparser_cls.boolops.keys()
        ) + list(unparser_cls.cmpops.keys())
    );
    node_names = [
        pascal_to_snake(method.replace("visit_", "")) for method in visit_methods
    ];
    pass_func_names = [];
    for (name, value) in inspect.getmembers(PyastBuildPass) {
        if name.startswith("proc_") and inspect.isfunction(value) {
            pass_func_names.append(name.replace("proc_", ""));
        }
    }
    for name in pass_func_names {
        assert name in node_names , f"Pass func {name} not in py_ast nodes";
    }
    for name in node_names {
        assert name in pass_func_names , f"py_ast node {name} not in pass funcs";
    }
}

test "str2doc" {
    with open(os.path.join(FIXTURES, "str2doc.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source), orig_src=Source(file_source, "str2doc.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();
    assert '"""This is a test function."""\ndef foo()' in code;
}

test "fstring triple quotes" {
    with open(os.path.join(FIXTURES, "py2jac_fstrings.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_fstrings.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();
    assert 'f"""Hello\n{name}"""' in code;
    assert "f'''Hello\n{name}'''''''" not in code;
    assert 'f"""Hello\n{name}"""""""' not in code;
}
