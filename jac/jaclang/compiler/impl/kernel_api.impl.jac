impl KernelRequest.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "source": self.source,
        "inputs": inputs_to_dict(self.inputs)
    };
}

impl KernelRequest.from_dict(raw: dict[str, any]) -> KernelRequest {
    source = raw.get("source");
    return KernelRequest(
        path=str(raw["path"]),
        source=str(source) if source is not None else None,
        inputs=inputs_from_dict(json_map(raw["inputs"]))
    );
}

impl compile_request(
    request: KernelRequest, asker: (HostAsker | None) = None
) -> CompileReport {
    run = run_kernel_session(request.inputs, request.path, request.source, True, asker);
    return CompileReport(
        analysis=run.outcome(request.path), units=list(run.host.units.values())
    );
}

impl check_request(
    request: KernelRequest, asker: (HostAsker | None) = None
) -> AnalysisReport {
    return run_kernel_session(
        request.inputs, request.path, request.source, False, asker
    ).outcome(
        request.path
    );
}
