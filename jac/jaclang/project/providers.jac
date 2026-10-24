import from pathlib { Path }

glob VENV_DEPS_MARKER: str = ".jac-deps-hash";


def _venv_deps_hash(specs: list[str]) -> str;


def venv_deps_satisfied(venv_dir: Path, specs: list[str]) -> bool;


def write_venv_deps_marker(venv_dir: Path, specs: list[str]);

obj ResolvedDependency {
    has name: str,
        version: str = "",
        ecosystem: str = "python",
        source: str = "pypi",
        origin: str = "manifest",
        dev: bool = False,
        data: dict[str, str] = {};
}

obj DependencyPlan {
    has deps: list[ResolvedDependency] = [];

    def for_ecosystem(name: str) -> list[ResolvedDependency];
    def ecosystems -> list[str];
    def is_empty -> bool;
}

obj InstallContext {
    has verbose: bool = False,
        install_flags: list[str] = [],
        target: str = "project";

    def is_dry_run -> bool;
}

obj EcosystemProvider {
    has name: str = "",
        manifest_key: str = "",
        cli_flag: str = "";

    def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency];

    def parse_spec(spec: str) -> tuple[str, str];
    def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool;

    def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None;

    def add_packages(
        config: JacConfig, specs: list[tuple[str, str]], dev: bool, ctx: InstallContext
    ) -> list[str] | None;

    def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool;

    def list_installed(config: JacConfig) -> list[str];
}

def manifest_plugin_deps(
    config: JacConfig, key: str
) -> tuple[dict[str, str], dict[str, str]];

def manifest_plugin_subdeps(
    config: JacConfig, key: str, section: str
) -> dict[str, str];

obj PythonProvider(EcosystemProvider) {
    has name: str = "python",
        manifest_key: str = "",
        cli_flag: str = "";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency];

    def resolve_extras(
        config: JacConfig, groups: list[str]
    ) -> list[ResolvedDependency];

    override def parse_spec(spec: str) -> tuple[str, str];
    def pip_spec(dep: ResolvedDependency) -> str;
    def freeze(config: JacConfig) -> list[str];
    def specs_for(deps: list[ResolvedDependency]) -> list[str];
    def _project_venv(config: JacConfig | None) -> Path;
    def _run_project_pip(
        config: JacConfig | None, args: list[str], verbose: bool = False
    ) -> tuple[int, str, str];

    def _snapshot_installed(
        config: JacConfig | None
    ) -> tuple[bool, set[tuple[str, str]]];

    def install_specs(
        config: JacConfig | None, specs: list[str], ctx: InstallContext
    ) -> bool;

    def _install_global(specs: list[str], ctx: InstallContext) -> bool;
    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool;

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None;

    override def add_packages(
        config: JacConfig, specs: list[tuple[str, str]], dev: bool, ctx: InstallContext
    ) -> list[str] | None;

    override def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool;

    def uninstall(config: JacConfig, name: str, ctx: InstallContext) -> bool;
    def is_installed(config: JacConfig, name: str) -> bool;
    def get_installed_version(config: JacConfig, name: str) -> str | None;
    override def list_installed(config: JacConfig) -> list[str];
}

def _major_minor(version: str) -> str;

obj ProviderRegistry {
    has _providers: dict[str, EcosystemProvider] = {},
        _order: list[str] = [];

    def register(provider: EcosystemProvider);
    def get(name: str) -> EcosystemProvider | None;
    def get_by_flag(flag: str) -> EcosystemProvider | None;
    def all -> list[EcosystemProvider];
    def `has(name: str) -> bool;
    def clear;
}

glob _registry: ProviderRegistry | None = None;

def get_provider_registry -> ProviderRegistry;

def get_python_provider -> PythonProvider;

def reset_provider_registry;

def initialize_provider_registry -> None;

def capability_dependencies(
    config: JacConfig,
    action: str = "",
    scale: bool = False,
    detected_intents: list[str] = []
) -> list[ResolvedDependency];

def _normalized_name(name: str) -> str;

def _declared_constraint(
    config: JacConfig, name: str, dev: bool
) -> tuple[str, str] | None;

def resolve_plan(
    config: JacConfig,
    include_dev: bool = False,
    extras: list[str] = [],
    action: str = "",
    scale: bool = False,
    detected_intents: list[str] = [],
    include_capabilities: bool = True
) -> DependencyPlan;
