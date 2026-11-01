impl options_record(options: CompileOptions) -> dict[str, any] {
    record: dict[str, any] = {};
    for name in KERNEL_OPTION_FIELDS {
        value = getattr(options, name);
        record[name] = list(value) if isinstance(value, list) else value;
    }
    return record;
}

impl compile_request_record(
    path: str, options: CompileOptions, source: (str | None) = None
) -> dict[str, any] {
    real = os.path.realpath(path);
    return {
        "paths": [real],
        "project_root": options.project_root or "",
        "options": options_record(options),
        "sources": {real: source} if source is not None else {},
        "products": list(KERNEL_PRODUCTS)
    };
}

impl check_request_record(
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    closure: bool = False,
    native_coverage: bool = False,
    placements: bool = False
) -> dict[str, any] {
    real = os.path.realpath(path);
    return {
        "paths": [real],
        "project_root": options.project_root or "",
        "options": options_record(options),
        "sources": {real: source} if source is not None else {},
        "closure": closure,
        "native_coverage": native_coverage,
        "placements": placements
    };
}

impl span_of_record(raw: dict[str, any]) -> DiagSpan {
    return DiagSpan(
        mod_path=raw["path"],
        first_line=raw["line"],
        last_line=raw["end_line"],
        col_start=raw["col"],
        col_end=raw["end_col"]
    );
}

impl diag_of_record(raw: dict[str, any]) -> AnalysisDiag {
    span = raw["span"];
    message: str = raw["message"];
    return AnalysisDiag(
        code=raw["code"],
        message=message.split("\n", 1)[0],
        path=span["path"],
        line=span["line"],
        col=span["col"],
        pass_name=raw["pass_name"],
        msg=message,
        span=span_of_record(span),
        related=[
            RelatedDiag(label=note["label"], span=span_of_record(note["span"]))
            for note in raw["related"]
        ],
        help_text=raw["help"] or None
    );
}

impl analysis_report_of(result: dict[str, any], entry_path: str) -> AnalysisReport {
    return AnalysisReport(
        entry_path=os.path.realpath(entry_path),
        modules=[ModuleReport(path=path) for path in result["reached"]],
        errors=[diag_of_record(d) for d in result["errors"]],
        warnings=[diag_of_record(d) for d in result["warnings"]]
    );
}

impl unit_of_record(raw: dict[str, any]) -> UnitProducts {
    return UnitProducts(
        path=raw["path"],
        code=raw["code"],
        placement=raw["placement"],
        client=raw["client_js"],
        native_iface=raw["native_iface"],
        native_deps=list(raw["native_deps"]),
        jac_deps=list(raw["jac_deps"])
    );
}

impl compile_report_of(result: dict[str, any], entry_path: str) -> CompileReport {
    analysis = analysis_report_of(result, entry_path);
    analysis.reads = [[read["path"], read["digest"]] for read in result["reads"]];
    return CompileReport(
        analysis=analysis, units=[unit_of_record(unit) for unit in result["units"]]
    );
}

impl kernel_analysis(
    path: str, options: CompileOptions, source: (str | None) = None
) -> dict[str, any] {
    return load_kernel().check(check_request_record(path, options, source));
}
