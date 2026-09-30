import from jaclang.packages.install {
    InstallError,
    load_lock,
    package_npm_requirements,
    package_pip_requirements
}
import from jaclang.project.config { JacConfig }
import from jaclang.project.providers {
    EcosystemProvider,
    InstallContext,
    ResolvedDependency
}

obj JacPackageProvider(EcosystemProvider) {
    has name: str = "jac",
        manifest_key: str = "",
        cli_flag: str = "";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency] {
        try {
            lock = load_lock(config) if config.project_root is not None else None;
        } except InstallError {
            lock = None;
        }
        if lock is None {
            return [];
        }
        out: list[ResolvedDependency] = [];
        for pkg in lock.packages {
            if pkg.dev and not include_dev {
                continue;
            }
            out.append(
                ResolvedDependency(
                    name=pkg.name,
                    version=pkg.version,
                    ecosystem="jac",
                    source=pkg.source_kind(),
                    origin="jac.lock",
                    dev=pkg.dev
                )
            );
        }
        for (name, spec, owner) in package_pip_requirements(lock, include_dev) {
            out.append(
                ResolvedDependency(
                    name=name,
                    version=spec,
                    ecosystem="python",
                    source="direct" if spec.startswith("@") else "pypi",
                    origin=f"package:{owner}"
                )
            );
        }
        for (name, spec, owner) in package_npm_requirements(lock, include_dev) {
            out.append(
                ResolvedDependency(
                    name=name,
                    version=spec,
                    ecosystem="npm",
                    source="npm",
                    origin=f"package:{owner}"
                )
            );
        }
        return out;
    }

    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool {
        return True;
    }
}
