"""List all installed packages from jac.toml."""

impl PackageInstaller.list_packages(
    self: PackageInstaller
) -> dict[str, dict[str, str]] {
    if not self.config_file.exists() {
        raise ClientBundleError(
            f'jac.toml not found at {self.config_file}. Run "jac init" first.'
        ) ;
    }
    config = self.config_loader.load();
    package_config = config.get('package', {});
    return {
        'dependencies': package_config.get('dependencies', {}),
        'devDependencies': package_config.get('devDependencies', {})
    };
}

"""Uninstall a package by removing it from jac.toml."""
impl PackageInstaller.uninstall_package(
    self: PackageInstaller, package_name: str, is_dev: bool = False
) -> None {
    if not self.config_file.exists() {
        raise ClientBundleError(
            f'jac.toml not found at {self.config_file}. Run "jac init" first.'
        ) ;
    }
    # Remove the dependency using JacClientConfig
    result = self.config_loader.remove_dependency(package_name, is_dev);
    if not result {
        deps_key = 'dev-dependencies' if is_dev else 'dependencies';
        raise ClientBundleError(f'Package "{package_name}" not found in {deps_key}') ;
    }
    # Save the updated config
    self.config_loader.save();
    # Regenerate package.json and run bun install to actually remove the package
    self._regenerate_and_install();
}

"""Regenerate package.json from jac.toml and run bun install."""
impl PackageInstaller._regenerate_and_install(self: PackageInstaller) -> None {
    import from jac_client.plugin.utils { ensure_bun_available }
    import from jaclang.cli.console { console }
    # Ensure bun is available before proceeding
    if not ensure_bun_available() {
        raise ClientBundleError('Bun is required. Install manually: https://bun.sh') from None ;
    }
    # Regenerate package.json from updated jac.toml
    bundler = ViteBundler(self.project_dir);
    bundler.create_package_json();
    # Ensure root package.json exists temporarily for bun commands
    bundler._ensure_root_package_json();
    try {
        # Run bun install to actually install the packages
        console.print("\n  ⏳ Installing packages...\n");
        result = subprocess.run(
            ['bun', 'install'], cwd=self.project_dir, check=False, text=True
        );
        if result.returncode != 0 {
            raise ClientBundleError('Failed to install packages (see output above)') ;
        }
        console.print("\n  ✔ Packages installed");
    } finally {
        # Always clean up root package.json and move bun.lockb
        bundler._cleanup_root_package_files();
    }
}

"""Install all packages from jac.toml (regenerate package.json and run bun install)."""
impl PackageInstaller.install_all(self: PackageInstaller) -> None {
    if not self.config_file.exists() {
        raise ClientBundleError(
            f'jac.toml not found at {self.config_file}. Run "jac init" first.'
        ) ;
    }
    self._regenerate_and_install();
}

"""Install a package by adding it to jac.toml."""
impl PackageInstaller.install_package(
    self: PackageInstaller,
    package_name: str,
    version: (str | None) = None,
    is_dev: bool = False
) -> None {
    if not self.config_file.exists() {
        raise ClientBundleError(
            f'jac.toml not found at {self.config_file}. Run "jac init" first.'
        ) ;
    }
    # Add package with version (default to latest if not specified)
    package_version = version or 'latest';
    # Use JacClientConfig to add the dependency
    self.config_loader.add_dependency(package_name, package_version, is_dev);
    # Save the updated config
    self.config_loader.save();
    # Regenerate package.json and install the package via bun
    self._regenerate_and_install();
}

"""Handles installing packages by updating jac.toml."""
impl PackageInstaller.init(self: PackageInstaller, project_dir: Path) {
    self.project_dir = project_dir;
    self.config_loader = JacClientConfig(project_dir);
    self.config_file = project_dir / 'jac.toml';
}
