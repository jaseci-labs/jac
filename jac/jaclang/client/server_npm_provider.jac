import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.project.providers {
    EcosystemProvider,
    InstallContext,
    ResolvedDependency,
    manifest_plugin_deps
}
import from jaclang.client.npm_provider {
    CORE_DEV_DEPS,
    LEGACY_META_PACKAGES,
    regenerate_and_install,
    target_scoped_npm_deps,
    resolve_client_target_name
}


def server_npm_root(project_dir: Path) -> Path {
    return project_dir / '.jac' / 'server';
}


def install_server_npm(project_dir: Path) {
    import from jaclang.client { get_bun }
    import from jaclang.client.bun_installer { bun_unavailable_message }
    import json;

    bun = get_bun();
    if not bun {
        raise RuntimeError(bun_unavailable_message()) from None;
    }
    npm_root = server_npm_root(project_dir);
    npm_root.mkdir(parents=True, exist_ok=True);
    pkg_path = npm_root / 'package.json';
    if not pkg_path.exists() {
        pkg = {
            'name': 'jac-server-deps',
            'private': True,
            'type': 'module',
            'dependencies': {},
            'devDependencies': {}
        };
        pkg_path.write_text(json.dumps(pkg, indent=2) + '\n', encoding='utf-8');
    }
    import subprocess;
    subprocess.run([bun, 'install'], cwd=str(npm_root), check=True);
}


obj ServerNpmProvider(EcosystemProvider) {
    has name: str = "server-npm",
        manifest_key: str = "npm",
        cli_flag: str = "--server";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency] {
        import from jaclang.client.npm_provider { NpmProvider }
        client = NpmProvider();
        return client.resolve(config, include_dev=include_dev);
    }

    override def parse_spec(spec: str) -> tuple[str, str] {
        import from jaclang.client.npm_provider { NpmProvider }
        return NpmProvider().parse_spec(spec);
    }

    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool {
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        install_server_npm(Path(str(config.project_root)));
        return True;
    }

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None {
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        config.add_dependency(name, version or 'latest', dev=dev, dep_type='npm');
        config.save();
        install_server_npm(Path(str(config.project_root)));
        return version or 'latest';
    }

    override def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool {
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        if not config.remove_dependency(name, dev=dev, dep_type='npm') {
            return False;
        }
        config.save();
        install_server_npm(Path(str(config.project_root)));
        return True;
    }
}
