import os;

obj DeployFactories {
    has utility: type[UtilityFactory],
        target: type[DeploymentTargetFactory];
}

def _load_deploy_factories -> DeployFactories;

def _print_local_fleet_banner(fleet: any);

def scale_local_serve(
    served: RunPlan,
    fleet: list[RunPlan],
    port: int = 8000,
    dev: bool = False,
    no_client: bool = False
) -> int | None;

def scale_deploy(
    filename: str,
    target: str,
    enable_tls: bool,
    dry_run: bool,
    show_yaml: bool,
    served_app: str = ""
) -> int;

def _resolve_deploy_target(target: str) -> tuple[str, str, str];

def _print_deployment_status(status_data: dict[str, any]) -> None;

def deploy_destroy(
    file_path: str, target: str = "kubernetes", component: str = ""
) -> int;

def deploy_status(file_path: str, target: str = "kubernetes") -> int;

comptime SPEC_SCALE_CMD: CommandSpec = CommandSpec(
         name="scale",
         help="Manage scale deployments: the local fleet of service apps (status/stop/restart/logs) and platform deployments (deploy/status/destroy of a workspace app)",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 help="Action: deploy, status, stop, restart, logs, destroy, gateway"
             ),
             Arg.create(
                 "service_name",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="App name (stop/restart/logs), the workspace app or .jac file to deploy, or a .jac app file for platform status/destroy"
             ),
             Arg.create(
                 "lines",
                 typ=int,
                 `default=50,
                 help="Number of log lines to show (for 'logs' action)"
             ),
             Arg.create(
                 "target",
                 typ=str,
                 `default="kubernetes",
                 help="Platform target for .jac app status/destroy (kubernetes, aws, gcp, etc.)"
             ),
             Arg.create(
                 "component",
                 typ=str,
                 `default="",
                 help="Platform destroy: component to remove (application, database, monitoring; default: entire deployment)"
             ),
             Arg.create(
                 "enable-tls",
                 typ=bool,
                 `default=False,
                 help="Platform deploy: enable HTTPS via Let's Encrypt (run after pointing your domain CNAME to the NLB)",
                 short=""
             ),
             Arg.create(
                 "dry-run",
                 typ=bool,
                 `default=False,
                 help="Platform deploy: print the manifests that would be applied; touch nothing (no cluster contact, no downloads, no client build, no DB provisioning, no TLS issuance, no deploy tooling installed)",
                 short=""
             ),
             Arg.create(
                 "show-yaml",
                 typ=bool,
                 `default=False,
                 help="Platform deploy, with --dry-run: dump the raw YAML stream",
                 short=""
             ),

         ],
         examples=[
             (
                 "jac scale deploy",
                 "Deploy the workspace's default app and its service apps"
             ),
             (
                 "jac scale deploy web",
                 "Deploy a named workspace app as the gateway host"
             ),
             ("jac scale deploy app.jac", "Deploy a specific app file"),
             (
                 "jac scale deploy app.jac --target aws",
                 "Deploy the app to a specific platform target"
             ),
             (
                 "jac scale deploy --dry-run --show-yaml",
                 "Print the manifests that would be applied, touching nothing"
             ),
             ("jac scale status", "Show status of the local fleet"),
             ("jac scale stop orders", "Stop the orders app"),
             ("jac scale restart cart", "Restart the cart app"),
             ("jac scale logs products", "Show logs for the products app"),
             ("jac scale destroy", "Stop every app in the local fleet"),
             ("jac scale status app.jac", "Show platform deployment status of app"),
             ("jac scale destroy app.jac", "Remove app's platform deployment"),
             (
                 "jac scale destroy app.jac --component database",
                 "Remove only the database from the deployment"
             ),

         ],
         group="fleet",
         handler_name=ct_name(scale_cmd)
     );

def scale_cmd(
    action: str,
    service_name: str = "",
    lines: int = 50,
    target: str = "kubernetes",
    component: str = "",
    enable_tls: bool = False,
    dry_run: bool = False,
    show_yaml: bool = False
) -> int;
