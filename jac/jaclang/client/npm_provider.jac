import from pathlib { Path }

glob CORE_RUNTIME_DEPS: dict[str, str] = {
         "react": "^19.2.0",
         "react-dom": "^19.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0"
     },
     OPTIONAL_RUNTIME_DEPS: dict[str, str] = {
         "@tanstack/react-form": "^1.33.0",
         "zod": "^4.3.6"
     },
     CORE_DEV_DEPS: dict[str, str] = {
         "vite": "^6.4.1",
         "@vitejs/plugin-react": "^4.7.0",
         "typescript": "^5.3.3",
         "@types/react": "^19.2.0",
         "@types/react-dom": "^19.2.0"
     },
     LEGACY_META_PACKAGES: set = {"jac-client-node", "@jac-client/dev-deps"};


def target_scoped_npm_deps(config: JacConfig, target_name: str) -> dict[str, str];


def _app_wants_client(config: JacConfig, app: any) -> bool;


def app_npm_deps(config: JacConfig) -> list[tuple[str, str, str, bool]];


def regenerate_and_install(project_dir: Path);


obj NpmProvider(EcosystemProvider) {
    has name: str = "npm",
        manifest_key: str = "npm",
        cli_flag: str = "--npm";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency];

    override def parse_spec(spec: str) -> tuple[str, str];
    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool;

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None;

    override def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool;
}
