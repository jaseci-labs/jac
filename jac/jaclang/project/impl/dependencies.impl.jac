import from jaclang.cli.console { console }

impl DependencyInstaller.postinit -> None {
    import from jaclang.project.config { get_config }
    if self.config is None {
        self.config = get_config();
    }
    if self.config is None {
        raise ValueError(
            "No jac.toml found. Run 'jac create <name>' to create a project."
        );
    }
    self.venv_dir = self.config.get_venv_dir();
    if self.install_flags is None {
        self.install_flags = [];
    }
}

impl DependencyInstaller.ensure_venv -> None {
    import venv;
    import sys;
    def _create_venv(target: Path) {
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
                ) from e;
            }
            raise;
        }
    }
    if self.venv_dir.exists() {
        pyvenv_cfg = self.venv_dir / "pyvenv.cfg";
        if sys.platform == "win32" {
            python_path = self.venv_dir / "Scripts" / "python.exe";
        } else {
            python_path = self.venv_dir / "bin" / "python";
        }
        if not pyvenv_cfg.exists() or not python_path.exists() {
            import shutil;
            if self.verbose {
                console.print(f"Recreating corrupted venv at {self.venv_dir}");
            }
            shutil.rmtree(self.venv_dir);
            _create_venv(self.venv_dir);
        }
    } else {
        if self.verbose {
            console.print(f"Creating venv at {self.venv_dir}");
        }
        self.venv_dir.parent.mkdir(parents=True, exist_ok=True);
        _create_venv(self.venv_dir);
    }

    site_packages = str(get_venv_site_packages(self.venv_dir));
    if site_packages not in sys.path {
        sys.path.insert(0, site_packages);
    }
}

impl pip_command(python: str, args: list[str]) -> list[str] {
    return [python, "-m", "pip"] + args;
}

impl DependencyInstaller._run_pip(args: list[str]) -> tuple[int, str, str] {
    import subprocess;
    import sys;

    if sys.platform == "win32" {
        venv_python = str(self.venv_dir / "Scripts" / "python.exe");
    } else {
        venv_python = str(self.venv_dir / "bin" / "python");
    }
    cmd = pip_command(venv_python, args);
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

impl DependencyInstaller.get_extra_package_specs(groups: list[str]) -> list[str] {
    if self.config is None {
        return [];
    }
    opt_deps = self.config.optional_dependencies;
    unknown: list[str] = [
        g
        for g in groups
        if g not in opt_deps
    ];
    if unknown {
        available: str = ", ".join(sorted(opt_deps.keys())) if opt_deps else "none";
        raise ValueError(
            f"Unknown extras: {', '.join(unknown)}. Available: {available}"
        );
    }
    pkg_key: str = self.config.project.name.lower().replace("_", "-");
    resolved: dict[str, str] = {};
    seen: set[str] = set();
    queue: list[str] = list(groups);
    while queue {
        group: str = queue.pop(0);
        if group in seen or group not in opt_deps {
            continue;
        }
        seen.add(group);
        for (name, ver) in opt_deps[group].items() {
            if "[" in name and name.endswith("]") {
                bracket: int = name.index("[");
                dep_pkg: str = name[:bracket].lower().replace("_", "-").strip();
                if dep_pkg == pkg_key {
                    queue.extend([g.strip() for g in name[bracket + 1:-1].split(",")]);
                    continue;
                }
            }
            resolved[name] = ver;
        }
    }
    return [self._make_pip_spec(name, ver) for (name, ver) in resolved.items()];
}

impl DependencyInstaller._make_pip_spec(name: str, version: str) -> str {
    if not version or version in ("*", "latest") {
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

impl DependencyInstaller._snapshot_installed -> tuple[bool, set[tuple]] {
    import json;
    try {
        (rc, out, _) = self._run_pip(["list", "--format=json"]);
        if rc == 0 {
            return (True, {(p["name"].lower(), p["version"]) for p in json.loads(out)});
        }
    } except Exception { }
    return (False, set());
}

impl DependencyInstaller.install_package(specs: list[str]) -> bool {
    if not specs {
        return True;
    }
    self.ensure_venv();
    is_dry_run = "--dry-run" in self.install_flags;
    (before_snapshot_ok, before_set) = (
        self._snapshot_installed() if not is_dry_run else (False, set())
    );
    (returncode, stdout, stderr) = self._run_pip(
        ["install", "--upgrade"] + self.install_flags + specs
    );
    if returncode == 0 {
        if is_dry_run {
            preview = stderr or stdout;
            if preview {
                console.print(preview, style="dim");
            }
            return True;
        }
        newly_installed: list[tuple] = [];
        (after_ok, after_set) = self._snapshot_installed();
        if after_ok and before_snapshot_ok {
            newly_installed = sorted(after_set - before_set);
        }
        if newly_installed {
            console.print("✔ Installation complete:", style="success");
            for (pkg_name, pkg_ver) in newly_installed {
                console.print(f"  ✓ {pkg_name}=={pkg_ver}", style="dim");
            }
        } else {
            console.print(
                f"✔ Successfully installed {len(specs)} package(s)", style="success"
            );
        }
        return True;
    }
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

    if not self.is_installed(name) {
        if self.verbose {
            console.print(f"  {name} was not installed");
        }
        return False;
    }
    (returncode, stdout, stderr) = self._run_pip(["uninstall", "-y", name]);
    if returncode == 0 {
        console.print(f"  {name} uninstalled successfully");
        return True;
    } else {
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

impl DependencyInstaller.get_installed_version(name: str) -> str | None {
    if not self.venv_dir or not self.venv_dir.exists() {
        return None;
    }
    (returncode, stdout, stderr) = self._run_pip(["show", name]);
    if returncode != 0 {
        return None;
    }

    for line in stdout.splitlines() {
        line = line.strip();
        if line.startswith("Version:") {
            version = line.split(":", 1)[1].strip();
            return version;
        }
    }
    return None;
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

        infrastructure = {"pip", "setuptools", "wheel"};
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

impl DependencyResolver.postinit -> None {
    import from jaclang.project.config { get_config }
    if self.config is None {
        self.config = get_config();
    }
    if self.config is None {
        raise ValueError("No jac.toml found.");
    }
}

impl DependencyResolver.parse_spec(spec: str) -> tuple[str, str] {
    import re;
    spec = spec.strip();

    npm_scoped_m = re.match(r"^(@[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+)@(.+)$", spec);
    if npm_scoped_m {
        return (npm_scoped_m.group(1), npm_scoped_m.group(2));
    }

    npm_m = re.match(r"^([a-zA-Z0-9_-]+)@(.+)$", spec);
    if npm_m {
        return (npm_m.group(1), npm_m.group(2));
    }

    py_m = re.match(r"^([a-zA-Z0-9_-]+)\s*([<>=!~]+.+)?$", spec);
    if py_m {
        name = py_m.group(1);
        version = py_m.group(2) or "";
        return (name, version);
    }

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

def _venv_python_version_tag(venv_dir: Path) -> str {
    pyvenv_cfg = venv_dir / "pyvenv.cfg";
    if not pyvenv_cfg.exists() {
        return "";
    }
    for line in pyvenv_cfg.read_text(encoding="utf-8").splitlines() {
        stripped = line.strip();
        if stripped.startswith("version") and "=" in stripped {
            version_str = stripped.split("=", 1)[1].strip();
            parts = version_str.split(".");
            if len(parts) >= 2 {
                return f"{parts[0]}.{parts[1]}";
            }
        }
    }
    return "";
}

def _discover_venv_site_packages(venv_dir: Path) -> Path | None {
    lib_dir = venv_dir / "lib";
    if not lib_dir.is_dir() {
        return None;
    }
    candidates: list[Path] = [];
    for child in lib_dir.iterdir() {
        if child.is_dir() and child.name.startswith("python") {
            site = child / "site-packages";
            if site.is_dir() {
                candidates.append(site);
            }
        }
    }
    if not candidates {
        return None;
    }
    candidates.sort(key=lambda p : p.parent.name, reverse=True);
    return candidates[0];
}

impl get_venv_site_packages(venv_dir: Path) -> Path {
    import sys;
    if sys.platform == "win32" {
        return venv_dir / "Lib" / "site-packages";
    }
    version_tag = _venv_python_version_tag(venv_dir);
    if version_tag {
        site_packages = venv_dir / "lib" / f"python{version_tag}" / "site-packages";
        if site_packages.is_dir() {
            return site_packages;
        }
    }
    discovered = _discover_venv_site_packages(venv_dir);
    if discovered is not None {
        return discovered;
    }

    if version_tag {
        return venv_dir / "lib" / f"python{version_tag}" / "site-packages";
    }
    return (
        venv_dir / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages"
    );
}

impl add_venv_to_path(config: JacConfig | None = None) -> None {
    import os;
    import sys;
    import from jaclang.project.config { get_config }
    if config is None {
        config = get_config();
    }
    if config is None {
        return;
    }
    venv_dir = config.get_venv_dir();
    site_packages = get_venv_site_packages(venv_dir);
    site_str = str(site_packages);
    if site_packages.exists() and site_str not in sys.path {
        sys.path.insert(0, site_str);
    }

    if sys.platform == "win32" {
        bin_dir = venv_dir / "Scripts";
    } else {
        bin_dir = venv_dir / "bin";
    }
    if bin_dir.exists() {
        bin_str = os.path.normpath(str(bin_dir.resolve()));
        current_path = os.environ.get("PATH", "");

        path_parts = [
            os.path.normpath(p)
            for p in current_path.split(os.pathsep)
            if p
        ];
        if bin_str not in path_parts {
            os.environ["PATH"] = bin_str + os.pathsep + current_path;
        }
    }
}

impl remove_venv_from_path(config: JacConfig | None = None) -> None {
    import os;
    import sys;
    import from jaclang.project.config { get_config }
    if config is None {
        config = get_config();
    }
    if config is None {
        return;
    }
    venv_dir = config.get_venv_dir();
    site_packages = get_venv_site_packages(venv_dir);
    site_str = str(site_packages);
    if site_str in sys.path {
        sys.path.remove(site_str);
    }

    if sys.platform == "win32" {
        bin_dir = venv_dir / "Scripts";
    } else {
        bin_dir = venv_dir / "bin";
    }

    bin_str = os.path.normpath(str(bin_dir.resolve()))
        if bin_dir.exists()
        else str(bin_dir);
    current_path = os.environ.get("PATH", "");
    path_parts = current_path.split(os.pathsep);

    new_parts = [
        p
        for p in path_parts
        if os.path.normpath(p) != bin_str
    ];
    if len(new_parts) != len(path_parts) {
        os.environ["PATH"] = os.pathsep.join(new_parts);
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
