"""Implementation of transform commands.

Direct implementations - no delegation to cli.jac.
"""

import ast as ast3;

import from jaclang.cli.console { console }

"""Convert Python to Jac."""
impl py2jac(filename: str) -> int {
    import jaclang.pycore.unitree as uni;
    import from jaclang.compiler.passes.main { PyastBuildPass }
    import from jaclang.pycore.program { JacProgram }
    import from jaclang.pycore.helpers { read_file_with_encoding }
    if filename.endswith('.py') {
        file_source = read_file_with_encoding(filename);
        code = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                ast3.parse(file_source), orig_src=uni.Source(file_source, filename)
            ),
            prog=JacProgram()
        ).ir_out.unparse(
            requires_format=False
        );
        prog = JacProgram.jac_str_formatter(
            source_str=code, file_path=filename, auto_lint=True
        );
        console.print(prog.mod.main.gen.jac);
        for error in prog.errors_had {
            console.error(f"{error}");
        }
        for w in prog.warnings_had {
            console.warning(f"{w}");
        }
    } else {
        console.error('Not a .py file.');
        return 1;
    }
    return 0;
}

"""Convert Jac to Python."""
impl jac2py(filename: str) -> int {
    import from jaclang.pycore.program { JacProgram }
    if filename.endswith('.jac') {
        code = JacProgram().compile(file_path=filename).gen.py;
        if code {
            console.print(code);
            return 0;
        } else {
            return 1;
        }
    } else {
        console.error('Not a .jac file.');
        return 1;
    }
}

"""Convert Jac to JavaScript."""
impl js(filename: str) -> int {
    import from jaclang.pycore.program { JacProgram }
    if filename.endswith('.jac') {
        try {
            prog = JacProgram();
            ir = prog.compile(file_path=filename);
            if prog.errors_had {
                for error in prog.errors_had {
                    console.error(f"{error}");
                }
                return 1;
            }
            js_output = ir.gen.js or '';
            if not js_output.strip() {
                console.error('ECMAScript code generation produced no output.');
                return 1;
            }
            console.print(js_output);
            return 0;
        } except Exception as e {
            console.error(f"Generating JavaScript failed: {e}");
            import traceback;
            traceback.print_exc();
            return 1;
        }
    } else {
        console.error('Not a .jac file.');
        return 1;
    }
}
