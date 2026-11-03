glob KERNEL_API_VERSION: int = 1;

obj KernelRequest {
    has path: str,
        source: (str | None) = None,
        inputs: KernelInputs = KernelInputs();

    def to_dict -> dict[str, any];
    static def from_dict(raw: dict[str, any]) -> KernelRequest;
}

def compile_request(
    request: KernelRequest, asker: (HostAsker | None) = None
) -> CompileReport;

def check_request(
    request: KernelRequest, asker: (HostAsker | None) = None
) -> AnalysisReport;
