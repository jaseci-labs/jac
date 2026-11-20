import os;
import pathlib;

glob DELEGATED_ENV: str = "JAC_SCALE_PINNED_DEPLOY",
     _K8S_TARGETS: tuple[str, ...] = ("kubernetes", "kubernetes-microservice"),
     _POD_ARCHS: tuple[str, ...] = ("x86_64", "aarch64");


def pinned_deploy_argv(
    jac_bin: str,
    filename: str,
    target: str,
    enable_tls: bool = False,
    from_build: str = "",
    plan_out: str = ""
) -> list[str];


def pinned_build_argv(
    jac_bin: str, filename: str, target: str, out_dir: str, arch: str
) -> list[str];


obj KubernetesRealizer {
    has fleet: (FleetSpec | None) = None,
        gateway_config: (dict[str, any] | None) = None,
        served_app: str = "";

    def _pinned_jac(filename: str) -> str;
    def _run_pinned(pinned: str, argv: list[str]) -> int;
    def _deploy_on_pinned_jac(
        filename: str,
        target: str,
        enable_tls: bool,
        dry_run: bool,
        from_build: str = "",
        plan_out: str = ""
    ) -> (int | None);

    def _resolve_fleet(code_folder: str) -> (FleetSpec | None);
    def _print_fleet_banner(fleet: FleetSpec | None) -> None;
    def _deployed_tree(filename: str, target: str) -> tuple[str, str];
    def _open_target(target: str, dry_run: bool) -> tuple[any, dict[str, any], any];
    def _app_config(
        deployment_target: any, scale_config: any, code_folder: str, entry_file: str
    ) -> AppConfig;

    def build(
        filename: str, target: str = "kubernetes", out_dir: str = "", arch: str = ""
    ) -> int;

    def realize(
        filename: str,
        target: str = "kubernetes",
        enable_tls: bool = False,
        dry_run: bool = False,
        show_yaml: bool = False,
        from_build: str = "",
        plan_out: str = ""
    ) -> int;
}
