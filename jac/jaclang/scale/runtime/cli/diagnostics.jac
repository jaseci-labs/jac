obj Diagnostic {
    has severity: str,
        message: str,
        service: str | None = None;
}


def _cpu_to_millicores(val: any) -> int | None;


def _mem_to_bytes(val: any) -> int | None;


obj PlanValidator {
    has bundle: any,
        routes: any = {},
        gateway_cfg: any = {},
        svc_configs: any = {};

    def run -> list[Diagnostic];
    def _check_config_keys(out: list[Diagnostic]);
    def _check_routes(routes: dict[str, any], out: list[Diagnostic]);
    def _check_hpa(
        svc_name: str, svc_cfg: any, deployment: any, out: list[Diagnostic]
    );

    def _check_pdb(
        svc_name: str, svc_cfg: any, deployment: any, out: list[Diagnostic]
    );

    def _check_resources(svc_name: str, deployment: any, out: list[Diagnostic]);
    def _check_image(svc_name: str, deployment: any, out: list[Diagnostic]);
}


def has_errors(diagnostics: list[Diagnostic]) -> bool;
