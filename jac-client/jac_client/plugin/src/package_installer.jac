"""Package installer for managing npm dependencies in config.json."""
import from __future__ { annotations }
import json;
import shutil;
import subprocess;
import from pathlib { Path }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .config_loader { JacClientConfig }
import from .vite_bundler { ViteBundler }

class PackageInstaller {
    """Handles installing npm packages by updating config.json."""
    def init(self: PackageInstaller, project_dir: Path) {
        self.project_dir = project_dir;
        self.config_loader = JacClientConfig(project_dir);
        self.config_file = project_dir / 'config.json';
    }

    """Install a package by adding it to config.json."""
    def install_package(
        self: PackageInstaller,
        package_name: str,
        version: (str | None) = None,
        is_dev: bool = False
    ) -> None {
        if not self.config_file.exists() {
            raise ClientBundleError(
                f'config.json not found at {self.config_file}. Run "jac generate_client_config" first.'
            ) ;
        }

        # Load current config
        config = self.config_loader.load();
        package_config = config.get('package', {});

        # Determine which dependencies dict to update
        if is_dev {
            deps_key = 'devDependencies';
        } else {
            deps_key = 'dependencies';
        }

        # Initialize dependencies dict if it doesn't exist
        if deps_key not in package_config {
            package_config[deps_key] = {};
        }

        # Add package with version (default to latest if not specified)
        package_version = version if version else 'latest';
        package_config[deps_key][package_name] = package_version;

        # Update config
        config['package'] = package_config;

        # Write updated config back to file
        with self.config_file.open('w', encoding='utf-8') as f {
            json.dump(config, f, indent=2);
        }

        # Regenerate package.json and install the package via npm
        self._regenerate_and_install();
    }

    """Install all packages from config.json (regenerate package.json and run npm install)."""
    def install_all(self: PackageInstaller) -> None {
        if not self.config_file.exists() {
            raise ClientBundleError(
                f'config.json not found at {self.config_file}. Run "jac generate_client_config" first.'
            ) ;
        }
        self._regenerate_and_install();
    }

    """Regenerate package.json from config.json and run npm install."""
    def _regenerate_and_install(self: PackageInstaller) -> None {
        # Regenerate package.json from updated config.json
        bundler = ViteBundler(self.project_dir);
        bundler.create_package_json();

        # Ensure root package.json exists temporarily for npm commands
        bundler._ensure_root_package_json();

        try {
            # Run npm install to actually install the packages
            subprocess.run(
                ['npm', 'install'],
                cwd=self.project_dir,
                check=True,
                capture_output=True,
                text=True
            );
        } except subprocess.CalledProcessError as e {
            raise ClientBundleError(f'Failed to install npm packages: {e.stderr}') from e ;
        } except FileNotFoundError {
            raise ClientBundleError(
                'npm command not found. Ensure Node.js and npm are installed.'
            ) from None ;
        } finally {
            # Always clean up root package.json and move package-lock.json
            bundler._cleanup_root_package_files();
        }
    }

    """Uninstall a package by removing it from config.json."""
    def uninstall_package(
        self: PackageInstaller, package_name: str, is_dev: bool = False
    ) -> None {
        if not self.config_file.exists() {
            raise ClientBundleError(
                f'config.json not found at {self.config_file}. Run "jac generate_client_config" first.'
            ) ;
        }

        # Load current config
        config = self.config_loader.load();
        package_config = config.get('package', {});

        # Determine which dependencies dict to update
        if is_dev {
            deps_key = 'devDependencies';
        } else {
            deps_key = 'dependencies';
        }

        # Remove package if it exists
        if (deps_key in package_config and package_name in package_config[deps_key]) {
            del package_config[deps_key][package_name] ;
            # Remove empty dict if no dependencies left
            if not package_config[deps_key] {
                package_config[deps_key] = {};
            }
        } else {
            raise ClientBundleError(
                f'Package "{package_name}" not found in {deps_key}'
            ) ;
        }

        # Update config
        config['package'] = package_config;

        # Write updated config back to file
        with self.config_file.open('w', encoding='utf-8') as f {
            json.dump(config, f, indent=2);
        }

        # Regenerate package.json and run npm install to actually remove the package
        self._regenerate_and_install();
    }

    """List all installed packages from config.json."""
    def list_packages(self: PackageInstaller) -> dict[str, dict[str, str]] {
        if not self.config_file.exists() {
            raise ClientBundleError(
                f'config.json not found at {self.config_file}. Run "jac generate_client_config" first.'
            ) ;
        }

        config = self.config_loader.load();
        package_config = config.get('package', {});

        return {
            'dependencies': package_config.get('dependencies', {}),
            'devDependencies': package_config.get('devDependencies', {})
        };
    }
}
