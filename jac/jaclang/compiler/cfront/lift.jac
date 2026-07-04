import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.main.cast_load_pass { CastBuildPass }

obj LiftResult {
    has module: uni.Module,
        diags: list[tuple[str, str, int]];
}

def lift_c_str(c_src: str, filename: str, lenient_c: bool = True) -> LiftResult {
    import from jaclang.vendor.pycparser { c_parser }
    parser = c_parser.CParser();
    try {
        file_ast = parser.parse(c_src, filename);
    } except Exception as e {
        if "Directive" in str(e) {
            raise ValueError(
                f"{filename}: lift_c_str expects already-preprocessed C, but the "
                f"input still has #include/#define/#pragma/#if directives. Preprocess "
                f"with pcpp (cfront.preprocess) first, or use the `jac c2jac` CLI."
            ) from e;
        }
        raise;
    }
    orig_src = uni.Source(c_src, filename);
    pass_ = CastBuildPass(
        ir_in=uni.CModuleAst(file_ast, orig_src=orig_src),
        prog=JacProgram(),
        lenient_c=lenient_c
    );
    return LiftResult(module=pass_.ir_out, diags=pass_.c_diag_records);
}

def transpile_c_str(c_src: str, filename: str, lenient_c: bool = True) -> str {
    res = lift_c_str(c_src, filename, lenient_c=lenient_c);
    return res.module.unparse(requires_format=True);
}

def lift_c_file(
    filename: str,
    include_dirs: list[str] | None = None,
    defines: list[str] | None = None,
    undefines: list[str] | None = None,
    force_includes: list[str] | None = None,
    nostdinc: bool = False,
    lenient_c: bool = True
) -> LiftResult {
    import from jaclang.jac0core.helpers { read_file_with_encoding }
    c_src = read_file_with_encoding(filename);
    if not filename.endswith(".i") {
        import from jaclang.compiler.cfront.preprocess { preprocess_c }
        c_src = preprocess_c(
            c_src,
            filename,
            include_dirs=include_dirs,
            defines=defines,
            undefines=undefines,
            force_includes=force_includes,
            nostdinc=nostdinc
        );
    }
    return lift_c_str(c_src, filename, lenient_c=lenient_c);
}

def _diag_sort_key(d: tuple) -> int {
    return d[2];
}

def render_c2jac_report(diags: list[tuple[str, str, int]]) -> str {
    if not diags {
        return "";
    }
    ordered = sorted(diags, key=_diag_sort_key);
    n = len(ordered);
    sites = "site" if n == 1 else "sites";
    lines = [
        f"# c2jac: {n} best-effort {sites} lowered with known infidelities "
        f"(surrogate calls to `__c_unsupported__` mark unliftable holes):"
    ];
    for (code, msg, line) in ordered {
        lines.append(f"#   L{line} [{code}] {msg}");
    }
    return "\n".join(lines) + "\n\n";
}
