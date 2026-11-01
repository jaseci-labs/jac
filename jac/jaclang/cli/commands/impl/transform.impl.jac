impl py2jac(filename: str) -> int {
    if not filename.endswith('.py') {
        console.error('Not a .py file.');
        return 1;
    }
    converted = tool_session().py_to_jac(filename);
    console.print(converted.text, markup=False, highlight=False);
    for error in converted.errors {
        console.error(diagnostic_text(error));
    }
    return 1 if converted.errors else 0;
}

impl jac2py(filename: str) -> int {
    if not filename.endswith('.jac') {
        console.error('Not a .jac file.');
        return 1;
    }
    compiled = call_compile(
        compile_request_for([filename], CompileOptions(), {}, ["python_ast"])
    );
    for error in compiled.errors {
        console.error(diagnostic_text(error));
    }
    if not compiled.ok() {
        return 1;
    }
    console.print(
        ast.unparse(compiled.unit(filename).python_ast), markup=False, highlight=False
    );
    return 0;
}

impl jac2js(filename: str) -> int {
    if not filename.endswith('.jac') {
        console.error('Not a .jac file.');
        return 1;
    }
    compiled = call_compile(
        compile_request_for([filename], CompileOptions(), {}, ["client_js"])
    );
    if not compiled.ok() {
        for error in compiled.errors {
            console.error(diagnostic_text(error));
        }
        return 1;
    }
    js_output = compiled.unit(filename).client_js;
    if not js_output.strip() {
        console.error('ECMAScript code generation produced no output.');
        return 1;
    }
    console.print(js_output, markup=False, highlight=False);
    return 0;
}
