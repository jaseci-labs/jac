import ast as ast3;

import from jaclang.cli.console { console }
import from jaclang.cli.commands.cli_helpers { flatten_append }

impl py2jac(filename: str) -> int {
    import jaclang.jac0core.unitree as uni;
    import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.helpers { read_file_with_encoding }
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

impl c2jac(
    filename: str,
    incdir: list | None = None,
    define: list | None = None,
    undef: list | None = None,
    force_include: list | None = None,
    nostdinc: bool = False
) -> int {
    import from jaclang.compiler.c2jac.driver { transpile_c_file }
    if not filename.endswith(".c") and not filename.endswith(".i") {
        console.error("Not a .c or .i file.");
        return 1;
    }
    try {
        (jac_str, tags) = transpile_c_file(
            filename,
            include_dirs=flatten_append(incdir),
            defines=flatten_append(define),
            undefines=flatten_append(undef),
            force_includes=flatten_append(force_include),
            nostdinc=nostdinc,
        );
    } except OSError as e {
        console.error(f"Cannot read {filename}: {e}");
        return 1;
    } except Exception as e {
        console.error(f"Transpilation failed: {e}");
        return 1;
    }
    console.print(jac_str, markup=False, highlight=False);
    import from jaclang.compiler.c2jac.comments { tier_b_site_count }

    n_tier_b = tier_b_site_count(tags);
    if n_tier_b {
        console.warning(
            f"[c2jac] {n_tier_b} best-effort (Tier-B) site(s) — see the `# c2jac:` "
            f"header in the output for the full list (surrogate sites are also "
            f"flagged inline at their site)"
        );
    }
    return 0;
}

def _csv_symbols(groups: list | None) -> list | None {
    flat = flatten_append(groups);
    if not flat {
        return None;
    }
    out: list = [];
    for raw in flat {
        for piece in raw.split(",") {
            sym = piece.strip();
            if sym {
                out.append(sym);
            }
        }
    }
    return out or None;
}

impl cbindgen(
    filename: str,
    lib: str | None = None,
    incdir: list | None = None,
    define: list | None = None,
    undef: list | None = None,
    force_include: list | None = None,
    nostdinc: bool = False,
    allow: list | None = None,
    block: list | None = None,
    output: str | None = None
) -> int {
    import from jaclang.compiler.c2jac.bindgen { generate_bindings }
    if not (
        filename.endswith(".h") or filename.endswith(".c") or filename.endswith(".i")
    ) {
        console.error("Not a .h, .c, or .i file.");
        return 1;
    }
    if not lib {
        console.error("cbindgen needs a target library: pass --lib <name>.");
        return 1;
    }
    try {
        (na_str, report) = generate_bindings(
            filename,
            lib,
            include_dirs=flatten_append(incdir),
            defines=flatten_append(define),
            undefines=flatten_append(undef),
            force_includes=flatten_append(force_include),
            nostdinc=nostdinc,
            allow=_csv_symbols(allow),
            block=_csv_symbols(block),
        );
    } except OSError as e {
        console.error(f"Cannot read {filename}: {e}");
        return 1;
    } except Exception as e {
        console.error(f"Binding generation failed: {e}");
        return 1;
    }
    if output {
        try {
            with open(output, "w") as f {
                f.write(na_str);
            }
        } except OSError as e {
            console.error(f"Cannot write {output}: {e}");
            return 1;
        }
        console.print(f"[cbindgen] wrote {report.functions} binding(s) to {output}");
    } else {
        console.print(na_str, markup=False, highlight=False);
    }
    if report.functions == 0 {
        console.warning(
            "[cbindgen] no extern function prototypes were bound — check -I "
            "include paths, --allow/--block filters, or that the header declares "
            "externs (Phase 0 binds functions only; structs/enums land in Phase 1)"
        );
    } elif report.variadic {
        console.warning(
            f"[cbindgen] {report.variadic} variadic binding(s) emit `*rest`: "
            f"va_list/va_arg semantics are not modelled — verify each call site"
        );
    }
    return 0;
}

impl jac2py(filename: str) -> int {
    import from jaclang.jac0core.program { JacProgram }
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
    import from jaclang.jac0core.program { JacProgram }
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
