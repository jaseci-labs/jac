import ast as ast3;

import from jaclang.cli.console { console }

impl py2jac(filename: str) -> int {
    import jaclang.compiler.frontend.unitree as uni;
    import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
    import from jaclang.compiler.tools.unparse_pass { unparse_module }
    import from jaclang.compiler.driver.pipeline { run_utility, UtilityProduct }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.project.source { read_file_with_encoding }
    if filename.endswith('.py') {
        file_source = read_file_with_encoding(filename);
        converted = run_utility(
            UtilityProduct.PYTHON_AST,
            uni.PythonModuleAst(
                ast3.parse(file_source), orig_src=uni.Source(file_source, filename)
            ),
            JacProgram()
        ).module;
        assert isinstance(converted, uni.Module);
        code = unparse_module(converted, requires_format=False);
        prog = JacProgram.jac_str_formatter(
            source_str=code, file_path=filename, auto_lint=False
        );
        console.print(prog.mod.main.gen.jac, markup=False, highlight=False);
        for error in prog.errors_had {
            console.error(f"{error}");
        }

        if prog.errors_had {
            return 1;
        }
    } else {
        console.error('Not a .py file.');
        return 1;
    }
    return 0;
}

impl jac2py(filename: str) -> int {
    import from jaclang.compiler.driver.program { JacProgram }
    if filename.endswith('.jac') {
        code = JacProgram().compile(file_path=filename).gen.py;
        if code {
            console.print(code, markup=False, highlight=False);
            return 0;
        } else {
            return 1;
        }
    } else {
        console.error('Not a .jac file.');
        return 1;
    }
}

impl jac2js(filename: str) -> int {
    import from jaclang.compiler.driver.program { JacProgram }
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
            console.print(js_output, markup=False, highlight=False);
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

impl c2jac(args: list[str]) -> int {
    import argparse;
    import os;
    import sys;
    import tempfile;
    import from jaclang.compiler.frontend.c.emitter { CEmitConfig, emit_c }
    import from jaclang.compiler.frontend.c.preprocessor { CConfig }

    parser = argparse.ArgumentParser(prog="jac tool c2jac",
        description="Translate the supported C subset into Jac source. Unsupported semantics are errors.");
    parser.add_argument("filename", help="C source file, or - for stdin");
    parser.add_argument("-o", "--output", `default="-", help="Output Jac file (default: stdout)");
    parser.add_argument("-I", "--include", action="append", `default=[], dest="include_paths", metavar="DIR",
        help="Include directory; may be repeated");
    parser.add_argument("-D", "--define", action="append", `default=[], dest="defines", metavar="NAME[=VALUE]",
        help="Predefine an object macro; missing VALUE means 1");
    parser.add_argument("--abi", choices=["lp64", "llp64", "ilp32"], `default="lp64",
        help="C integer data model (default: lp64; does not select a Jac native target)");
    parser.add_argument("--unsigned-char", action="store_true", help="Treat plain C char as unsigned");
    try { options = parser.parse_args(args); }
    except SystemExit as error { return int(error.code or 0); }
    filename = str(options.filename); destination = str(options.output);
    try {
        definitions: dict[str, str] = {};
        for definition in options.defines {
            pieces = str(definition).split("=", 1); name = pieces[0];
            if not name or not (name[0].isalpha() or name[0] == "_") or not all(c.isalnum() or c == "_" for c in name) {
                raise ValueError("Invalid -D macro name: " + name);
            }
            definitions[name] = pieces[1] if len(pieces) == 2 else "1";
        }
        if filename == "-" { source = sys.stdin.read(); path = "<stdin>"; }
        else {
            path = os.path.abspath(filename);
            with open(path, encoding="utf-8") as stream { source = stream.read(); }
        }
        if destination != "-" and filename != "-" {
            if os.path.realpath(destination) == os.path.realpath(path) or (os.path.exists(destination) and os.path.samefile(destination, path)) {
                raise ValueError("Output path must not overwrite the C input");
            }
        }
        result = emit_c(source, path,
            CConfig(include_paths=list(options.include_paths), defines=definitions),
            CEmitConfig(abi=str(options.abi), char_signed=not bool(options.unsigned_char)));
        for diagnostic in result.diagnostics { sys.stderr.write(str(diagnostic) + "\n"); }
        if not result.ok { return 1; }
        if destination == "-" { sys.stdout.write(result.source); }
        else {
            directory = os.path.dirname(os.path.abspath(destination)); temporary = "";
            try {
                with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n",
                    dir=directory, prefix=".c2jac-", suffix=".jac", delete=False) as stream {
                    temporary = stream.name; stream.write(result.source);
                }
                os.replace(temporary, destination); temporary = "";
            } finally {
                if temporary and os.path.exists(temporary) { os.unlink(temporary); }
            }
        }
        return 0;
    } except (OSError, UnicodeError, ValueError) as error {
        sys.stderr.write("c2jac: " + str(error) + "\n"); return 1;
    }
}
