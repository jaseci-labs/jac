import os;
import pathlib;

glob DELEGATED_ENV: str = "JAC_SCALE_PINNED_DEPLOY";


def pinned_deploy_argv(
    jac_bin: str, filename: str, target: str, enable_tls: bool = False
) -> list[str];


obj KubernetesRealizer {
    has fleet: (FleetSpec | None) = None,
        gateway_config: (dict[str, any] | None) = None,
        served_app: str = "";

    def _deploy_on_pinned_jac(
        filename: str, target: str, enable_tls: bool, dry_run: bool
    ) -> (int | None);

    def _resolve_fleet(code_folder: str) -> (FleetSpec | None);
    def _print_fleet_banner(fleet: FleetSpec | None) -> None;
    def realize(
        filename: str,
        target: str = "kubernetes",
        enable_tls: bool = False,
        dry_run: bool = False,
        show_yaml: bool = False
    ) -> int;
}
