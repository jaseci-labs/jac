obj JacPackageProvider(EcosystemProvider) {
    has name: str = "jac",
        manifest_key: str = "",
        cli_flag: str = "";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency];

    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool;
}
