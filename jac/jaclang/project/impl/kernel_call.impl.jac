impl options_record(options: CompileOptions) -> dict[str, any] {
    record: dict[str, any] = {};
    for name in KERNEL_OPTION_FIELDS {
        value = getattr(options, name);
        record[name] = list(value) if isinstance(value, list) else value;
    }
    return record;
}

impl compile_request_record(request: CompileRequest) -> dict[str, any] {
    return {
        "paths": list(request.paths),
        "project_root": request.project_root,
        "search_paths": list(request.search_paths),
        "package_root": request.package_root,
        "options": options_record(request.options),
        "sources": dict(request.sources),
        "products": list(request.products)
    };
}

impl check_request_record(request: CheckRequest) -> dict[str, any] {
    return {
        "paths": list(request.paths),
        "project_root": request.project_root,
        "search_paths": list(request.search_paths),
        "package_root": request.package_root,
        "options": options_record(request.options),
        "sources": dict(request.sources),
        "native_coverage": request.native_coverage,
        "placements": request.placements,
        "closure": request.closure
    };
}

impl kernel_build_request_record(request: KernelBuildRequest) -> dict[str, any] {
    return {
        "target": request.target.to_dict(),
        "output": request.output,
        "triple": request.triple,
        "search_paths": list(request.search_paths),
        "package_root": request.package_root
    };
}

impl span_of_record(raw: dict[str, any]) -> SourceSpan {
    return SourceSpan(
        path=raw["path"],
        line=raw["line"],
        col=raw["col"],
        end_line=raw["end_line"],
        end_col=raw["end_col"]
    );
}

impl diagnostic_of_record(raw: dict[str, any]) -> KernelDiagnostic {
    return KernelDiagnostic(
        code=raw["code"],
        severity=raw["severity"],
        message=raw["message"],
        span=span_of_record(raw["span"]),
        help=raw["help"],
        pass_name=raw["pass_name"],
        related=[
            RelatedNote(label=note["label"], span=span_of_record(note["span"]))
            for note in raw["related"]
        ]
    );
}

impl demotion_of_record(raw: dict[str, any]) -> NativeDemotion {
    return NativeDemotion(
        symbol=raw["symbol"],
        kind=raw["kind"],
        reason=raw["reason"],
        code=raw["code"],
        span=span_of_record(raw["span"])
    );
}

impl unit_of_record(raw: dict[str, any]) -> CompiledUnit {
    return CompiledUnit(
        path=raw["path"],
        module_name=raw["module_name"],
        code=raw["code"],
        interface=raw["interface"],
        placement=raw["placement"],
        client_js=raw["client_js"],
        native_object=raw["native_object"],
        native_iface=raw["native_iface"],
        native_deps=list(raw["native_deps"]),
        native_ir=raw["native_ir"],
        native_mir=raw["native_mir"],
        native_layout=raw["native_layout"],
        demoted=[demotion_of_record(row) for row in raw["demoted"]],
        jac_deps=list(raw["jac_deps"]),
        app=raw["app"],
        persistence=list(raw["persistence"]),
        import_edges=list(raw["import_edges"]),
        interop=raw["interop"],
        client_manifest=raw["client_manifest"],
        iface_shape=raw["iface_shape"],
        effects=raw["effects"],
        sections=dict(raw["sections"])
    );
}

impl compile_result_of(raw: dict[str, any]) -> CompileResult {
    return CompileResult(
        units=[unit_of_record(unit) for unit in raw["units"]],
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]],
        warnings=[diagnostic_of_record(diag) for diag in raw["warnings"]],
        reached=list(raw["reached"]),
        reads=[
            SourceRead(path=read["path"], digest=read["digest"])
            for read in raw["reads"]
        ]
    );
}

impl check_result_of(raw: dict[str, any]) -> CheckResult {
    return CheckResult(
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]],
        warnings=[diagnostic_of_record(diag) for diag in raw["warnings"]],
        reached=list(raw["reached"]),
        coverage=[
            CoverageRow(
                path=row["path"],
                native=row["native"],
                demoted=[demotion_of_record(item) for item in row["demoted"]]
            )
            for row in raw["coverage"]
        ],
        placements=[
            PlacementRow(
                path=row["path"],
                symbol=row["symbol"],
                placement=row["placement"],
                reason=row["reason"]
            )
            for row in raw["placements"]
        ]
    );
}

impl kernel_build_result_of(raw: dict[str, any]) -> KernelBuildResult {
    return KernelBuildResult(
        output=raw["output"],
        triple=raw["triple"],
        artifact_sha256=raw["artifact_sha256"],
        plan_digest=raw["plan_digest"],
        units=raw["units"],
        errors=[diagnostic_of_record(diag) for diag in raw["errors"]],
        warnings=[diagnostic_of_record(diag) for diag in raw["warnings"]],
        inputs=[
            SourceRead(path=read["path"], digest=read["digest"])
            for read in raw["inputs"]
        ]
    );
}

impl call_compile(request: CompileRequest) -> CompileResult {
    kernel = load_kernel();
    try {
        raw = kernel.compile(compile_request_record(request));
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return compile_result_of(raw);
}

impl call_check(request: CheckRequest) -> CheckResult {
    kernel = load_kernel();
    try {
        raw = kernel.check(check_request_record(request));
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return check_result_of(raw);
}

impl call_build_kernel(request: KernelBuildRequest) -> KernelBuildResult {
    kernel = load_kernel();
    try {
        raw = kernel.build_kernel(kernel_build_request_record(request));
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return kernel_build_result_of(raw);
}

impl open_kernel_session(project_root: str) -> any {
    kernel = load_kernel();
    try {
        return kernel.open_session(project_root, list(sys.path), package_root());
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
}

impl kernel_tests -> list[KernelTestCase] {
    kernel = load_kernel();
    try {
        raw = kernel.tests();
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return [KernelTestCase(suite=row["suite"], name=row["name"]) for row in raw];
}

impl call_kernel_tests(
    suite: str, scratch: str, names: (list[str] | None) = None
) -> list[KernelTestOutcome] {
    kernel = load_kernel();
    try {
        raw = kernel.run_tests(
            {
                "suite": suite,
                "scratch": scratch,
                "names": list(names or []),
                "search_paths": list(sys.path),
                "package_root": package_root()
            }
        );
    } except kernel.KernelError as error {
        raise KernelError(str(error)) from error;
    }
    return [
        KernelTestOutcome(
            suite=row["suite"],
            name=row["name"],
            passed=row["passed"],
            message=row["message"]
        )
        for row in raw
    ];
}
