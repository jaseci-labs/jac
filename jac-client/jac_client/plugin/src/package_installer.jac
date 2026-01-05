"""Package installer for managing npm dependencies in jac.toml."""

import shutil;
import subprocess;
import from pathlib { Path }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .config_loader { JacClientConfig }
import from .vite_bundler { ViteBundler }

class PackageInstaller {
    def init(self: PackageInstaller, project_dir: Path);
    def install_package(
        self: PackageInstaller,
        package_name: str,
        version: (str | None) = None,
        is_dev: bool = False
    ) -> None;

    def install_all(self: PackageInstaller) -> None;
    def _regenerate_and_install(self: PackageInstaller) -> None;
    def uninstall_package(
        self: PackageInstaller, package_name: str, is_dev: bool = False
    ) -> None;

    def list_packages(self: PackageInstaller) -> dict[str, dict[(str, str)]];
}
