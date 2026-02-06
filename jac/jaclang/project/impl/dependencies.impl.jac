"""Implementation of dependency management for Jac projects."""

import from jaclang.cli.console { console }

# ===============================================================================
# DependencyInstaller Implementation
# ===============================================================================
impl DependencyInstaller.postinit -> None {
    import from jaclang.project.config { get_config }
    if self.config is None {
        self.config = get_config();
    }
    if self.config is None {
        raise ValueError("No jac.toml found. Run 'jac init' to create a project.") ;
    }
    self.venv_dir = self.config.get_venv_dir();
}

impl DependencyInstaller.ensure_venv -> None {
    import venv;
    import sys;
    def _create_venv(target: Path) -> None {
        builder = venv.EnvBuilder(with_pip=True, symlinks=(sys.platform != "win32"));
        try {
            builder.create(str(target));
        } except Exception as e {
            err_msg = str(e).lower();
            if "ensurepip" in err_msg or "no module named" in err_msg {
                raise RuntimeError(
                    "Failed to create virtual environment: ensurepip is not available.\n"
                    "On Debian/Ubuntu, install it with: sudo apt install python3-venv\n"
                    "On Fedora/RHEL: sudo dnf install python3-libs"
                ) from e ;
            }
            raise ;
        }
    }
    if self.venv_dir.exists() {
        # Validate the venv is not corrupted by checking for pyvenv.cfg and python binary
        pyvenv_cfg = self.venv_dir / "pyvenv.cfg";
        if sys.platform == "win32" {
            python_path = self.venv_dir / "Scripts" / "python.exe";
        } else {
            python_path = self.venv_dir / "bin" / "python";
        }
        if not pyvenv_cfg.exists() or not python_path.exists() {
            # Corrupted venv - recreate
            import shutil;
            if self.verbose {
                console.print(f"Recreating corrupted venv at {self.venv_dir}");
            }
            shutil.rmtree(self.venv_dir);
            _create_venv(self.venv_dir);
        }
    } else {
        # Create new venv
        if self.verbose {
            console.print(f"Creating venv at {self.venv_dir}");
        }
        self.venv_dir.parent.mkdir(parents=True, exist_ok=True);
        _create_venv(self.venv_dir);
    }
    # Add venv site-packages to sys.path
    site_packages = str(get_venv_site_packages(self.venv_dir));
    if site_packages not in sys.path {
        sys.path.insert(0, site_packages);
    }
}

impl DependencyInstaller._run_pip(args: list[str]) -> tuple[int, str, str] {
    import subprocess;
    import sys;
    # Use the venv's own Python to run pip
    if sys.platform == "win32" {
        venv_python = str(self.venv_dir / "Scripts" / "python.exe");
    } else {
        venv_python = str(self.venv_dir / "bin" / "python");
    }
    cmd = [venv_python, "-m", "pip"] + args;
    if self.verbose {
        console.print(f"Running: {' '.join(cmd)}");
    }
    try {
        result = subprocess.run(cmd, capture_output=True, text=True);
        return (result.returncode, result.stdout, result.stderr);
    } except Exception as e {
        return (1, "", str(e));
    }
}

impl DependencyInstaller.get_pip_package_specs(include_dev: bool = False) -> list[str] {
    specs: list[str] = [];
    for (name, version) in self.config.dependencies.items() {
        specs.append(self._make_pip_spec(name, version));
    }
    if include_dev {
        for (name, version) in self.config.dev_dependencies.items() {
            specs.append(self._make_pip_spec(name, version));
        }
    }
    return specs;
}

impl DependencyInstaller.get_git_package_specs -> list[str] {
    specs: list[str] = [];
    for (name, git_info) in self.config.git_dependencies.items() {
        if isinstance(git_info, dict) and "git" in git_info {
            git_url = git_info.get("git", "");
            branch = git_info.get("branch", "");
            spec = self._make_git_spec(name, git_url, branch);
            specs.append(spec);
        }
    }
    return specs;
}

"""Create pip spec from package name and version."""
impl DependencyInstaller._make_pip_spec(name: str, version: str) -> str {
    if not version {
        return name;
    }
    if version.startswith(("=", ">", "<", "~", "!")) {
        return f"{name}{version}";
    }
    return f"{name}=={version}";
}

impl DependencyInstaller._make_git_spec(
    name: str, git_url: str, branch: str = ""
) -> str {
    if branch {
        return f"git+{git_url}@{branch}";
    }
    return f"git+{git_url}";
}

"""Install packages given a list of pip specs."""
impl DependencyInstaller.install_package(specs: list[str]) -> bool {
    if not specs {
        return True;
    }
    self.ensure_venv();
    import re;
    (returncode, stdout, stderr) = self._run_pip(["install", "--upgrade"] + specs);
    if returncode == 0 {
        # Parse and display what was actually installed
        if "Successfully installed" in stdout {
            console.print("✔ Installation complete:", style="success");
            # Extract installed packages from pip output
            installed = re.search(r"Successfully installed (.+)", stdout);
            if installed {
                packages = installed.group(1).split();
                for pkg in packages {
                    console.print(f"  ✓ {pkg}", style="dim");
                }
            }
        } else {
            console.print(
                f"✔ Successfully installed {len(specs)} package(s)", style="success"
            );
        }
        return True;
    }
    # Batch failed - show error and suggest checking for conflicts
    console.error(f"✗ Batch installation failed: {stderr}");
    console.print("  Tip: Check for version conflicts in jac.toml", style="muted");
    return False;
}

impl DependencyInstaller.uninstall_package(name: str) -> bool {
    import sys;
    if not self.venv_dir or not self.venv_dir.exists() {
        return False;
    }
    console.print(f"Uninstalling {name}...");
    (returncode, stdout, stderr) = self._run_pip(["uninstall", "-y", name]);
    if returncode == 0 {
        console.print(f"  {name} uninstalled successfully");
        return True;
    } else {
        if "not installed" in stderr.lower() or "not installed" in stdout.lower() {
            if self.verbose {
                console.print(f"  {name} was not installed");
            }
            return False;
        }
        console.error(f"  Failed to uninstall {name}: {stderr}");
        return False;
    }
}

impl DependencyInstaller.is_installed(name: str) -> bool {
    if not self.venv_dir or not self.venv_dir.exists() {
        return False;
    }
    (returncode, stdout, stderr) = self._run_pip(["show", name]);
    return returncode == 0;
}

impl DependencyInstaller.list_installed -> list[str] {
    import json;
    if not self.venv_dir or not self.venv_dir.exists() {
        return [];
    }
    (returncode, stdout, stderr) = self._run_pip(["list", "--format=json"]);
    if returncode != 0 {
        return [];
    }
    try {
        packages_data = json.loads(stdout);
        # Filter out venv infrastructure packages
        infrastructure = {"pip","setuptools","wheel"};
        return sorted(
            [
                pkg["name"]
                for pkg in packages_data
                if pkg["name"].lower() not in infrastructure
            ]
        );
    } except (json.JSONDecodeError, KeyError) {
        return [];
    }
}

# ===============================================================================
# DependencyResolver Implementation
# ===============================================================================
impl DependencyResolver.postinit -> None {
    import from jaclang.project.config { get_config }
    if self.config is None {
        self.config = get_config();
    }
    if self.config is None {
        raise ValueError("No jac.toml found.") ;
    }
}

impl DependencyResolver.parse_spec(spec: str) -> tuple[str, str] {
    import re;
    spec = spec.strip();
    # Handle npm scoped packages: @scope/name@version
    npm_scoped_m = re.match(r"^(@[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+)@(.+)$", spec);
    if npm_scoped_m {
        return (npm_scoped_m.group(1), npm_scoped_m.group(2));
    }
    # Handle npm style: name@version
    npm_m = re.match(r"^([a-zA-Z0-9_-]+)@(.+)$", spec);
    if npm_m {
        return (npm_m.group(1), npm_m.group(2));
    }
    # Handle Python style: name>=version, name~=version, etc.
    py_m = re.match(r"^([a-zA-Z0-9_-]+)\s*([<>=!~]+.+)?$", spec);
    if py_m {
        name = py_m.group(1);
        version = py_m.group(2) or "";
        return (name, version);
    }
    # Handle scoped packages without version: @scope/name
    if spec.startswith("@") and "/" in spec {
        return (spec, "");
    }
    return (spec, "");
}

impl DependencyResolver.resolve(include_dev: bool = False) -> list[ResolvedDependency] {
    resolved = [];
    for (name, version) in self.config.dependencies.items() {
        resolved.append(ResolvedDependency(name=name, version=version, source="pypi"));
    }
    if include_dev {
        for (name, version) in self.config.dev_dependencies.items() {
            resolved.append(
                ResolvedDependency(name=name, version=version, source="pypi")
            );
        }
    }
    for (name, git_info) in self.config.git_dependencies.items() {
        if isinstance(git_info, dict) {
            resolved.append(
                ResolvedDependency(
                    name=name, version=git_info.get("branch", "main"), source="git"
                )
            );
        }
    }
    return resolved;
}

# ===============================================================================
# Venv Site-Packages Helper
# ===============================================================================
impl get_venv_site_packages(
    venv_dir: Path
) -> Path {
    import sys;
    if sys.platform == "win32" {
        return venv_dir / "Lib" / "site-packages";
    } else {
        return venv_dir / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages";
    }
}

# ===============================================================================
# Venv Path Management Implementation
# ===============================================================================
impl add_venv_to_path(
    config: JacConfig | None = None
) -> None {
    import sys;
    import from jaclang.project.config { get_config }
    if config is None {
        config = get_config();
    }
    if config is None {
        return;
    }
    site_packages = get_venv_site_packages(config.get_venv_dir());
    site_str = str(site_packages);
    if site_packages.exists() and site_str not in sys.path {
        sys.path.insert(0, site_str);
    }
}

impl remove_venv_from_path(config: JacConfig | None = None) -> None {
    import sys;
    import from jaclang.project.config { get_config }
    if config is None {
        config = get_config();
    }
    if config is None {
        return;
    }
    site_packages = get_venv_site_packages(config.get_venv_dir());
    site_str = str(site_packages);
    if site_str in sys.path {
        sys.path.remove(site_str);
    }
}

impl is_venv_in_path(config: JacConfig | None = None) -> bool {
    import sys;
    import from jaclang.project.config { get_config }
    if config is None {
        config = get_config();
    }
    if config is None {
        return False;
    }
    site_packages = get_venv_site_packages(config.get_venv_dir());
    return str(site_packages) in sys.path;
}
