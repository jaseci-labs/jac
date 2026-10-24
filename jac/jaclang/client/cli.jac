import os;

import from pathlib { Path }

comptime SPEC_SETUP: CommandSpec = CommandSpec(
         name="setup",
         help="Provision an app's client ahead of time (run and build do it on first use)",
         args=[
             Arg.create(
                 "target",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="App name from [apps]; omit to set up the default app"
             ),
             Arg.create(
                 "toolchain",
                 `default="",
                 help="Provision build tools without a project: android, ios, desktop, cef"
             ),
             Arg.create(
                 "platform",
                 `default="",
                 help="Also provision the app build platform: android or ios"
             )
         ],
         examples=[
             ("jac setup", "Set up the default app's client"),
             (
                 "jac setup mobile",
                 "Scaffold the Expo project for the app named 'mobile'"
             )
         ],
         group="project",
         handler_name=ct_name(setup)
     );

def setup(target: str = "", toolchain: str = "", platform: str = "") -> int;

def run_client_setup(app: AppConfig) -> int;

def _place_bundle(bundle_path: Path, out_dir: Path) -> Path;

def run_client_build(
    app: AppConfig,
    platform: str | None,
    entry_override: str = "",
    output: str = "",
    kind: str = ""
) -> int;

def run_client_start(
    app: AppConfig,
    host: str,
    platform: str,
    port: int,
    api_port: int,
    dev: bool,
    no_client: bool,
    tunnel: bool = False
) -> int | None;

def get_config -> JacConfig | None;

def _npm_context -> tuple[JacConfig, EcosystemProvider] | None;

def run_npm_add(packages: list[str], dev: bool, install_global: bool = False) -> int;

def run_npm_add_global(packages: list[str], dev: bool) -> int;

def run_npm_remove(packages: list[str], dev: bool) -> int;
