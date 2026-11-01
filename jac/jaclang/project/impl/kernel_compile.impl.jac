impl compile_request_for(
    paths: list[str],
    options: CompileOptions,
    sources: dict[str, str],
    products: list[str]
) -> CompileRequest {
    return CompileRequest(
        paths=[os.path.realpath(path) for path in paths],
        project_root=options.project_root or "",
        search_paths=list(sys.path),
        package_root=package_root(),
        options=options,
        sources={os.path.realpath(path): text for (path, text) in sources.items()},
        products=products
    );
}

impl check_request_for(
    paths: list[str],
    options: CompileOptions,
    native_coverage: bool = False,
    placements: bool = False,
    closure: bool = False
) -> CheckRequest {
    return CheckRequest(
        paths=[os.path.realpath(path) for path in paths],
        project_root=options.project_root or "",
        search_paths=list(sys.path),
        package_root=package_root(),
        options=options,
        native_coverage=native_coverage,
        placements=placements,
        closure=closure
    );
}

impl span_of(record: SourceSpan) -> Span {
    return Span(
        mod_path=record.path,
        first_line=record.line,
        last_line=record.end_line,
        col_start=record.col,
        col_end=record.end_col
    );
}

impl alert_of(diag: KernelDiagnostic) -> Alert {
    return Alert(
        msg=diag.message,
        loc=span_of(diag.span),
        from_pass=KernelReported,
        code=DIAGNOSTICS[diag.code] if diag.code else None,
        related=[(note.label, span_of(note.span)) for note in diag.related],
        help_text=diag.help or None
    );
}

impl adopt_diagnostics(
    program: JacProgram, errors: list[KernelDiagnostic], warnings: list[KernelDiagnostic]
) {
    for diag in errors {
        program.errors_had.append(alert_of(diag));
    }
    for diag in warnings {
        program.warnings_had.append(alert_of(diag));
    }
}

impl kernel_compile(
    program: JacProgram,
    paths: list[str],
    options: CompileOptions,
    sources: (dict[str, str] | None) = None,
    products: (list[str] | None) = None
) -> CompileResult {
    wanted = products if products is not None else ([] if options.no_cgen else ["bytecode"]);
    result = call_compile(compile_request_for(paths, options, sources or {}, wanted));
    adopt_diagnostics(program, result.errors, result.warnings);
    return result;
}

impl compile_through_kernel(
    program: JacProgram, file_path: str, use_str: (str | None), options: CompileOptions
) -> uni.Module {
    real = os.path.realpath(file_path);
    sources = {real: use_str} if use_str is not None else {};
    result = kernel_compile(program, [real], options, sources);
    module = uni.Module.make_stub(inject_name=os.path.splitext(os.path.basename(real))[0]);
    module.loc.mod_path = real;
    if options.no_cgen or not result.ok() {
        return module;
    }
    unit = result.unit(real);
    module.gen.py_bytecode = marshal.dumps(unit.code);
    module.gen.js = unit.client_js;
    return module;
}

impl kernel_compile_application(
    program: JacProgram, paths: list[str], options: CompileOptions
) -> CompileResult {
    result = kernel_compile(program, paths, options);
    for unit in result.units {
        _APPLICATION_UNITS[os.path.realpath(unit.path)] = unit;
    }
    return result;
}

impl take_application_unit(path: str) -> (CompiledUnit | None) {
    return _APPLICATION_UNITS.pop(os.path.realpath(path), None);
}

impl forget_application_units {
    _APPLICATION_UNITS.clear();
}
