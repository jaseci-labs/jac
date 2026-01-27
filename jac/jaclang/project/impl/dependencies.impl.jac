"""Implementation of dependency management for Jac projects."""

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
    self.packages_dir = self.config.get_packages_dir();
}

impl DependencyInstaller.ensure_packages_dir -> None {
    import sys;
    self.packages_dir.mkdir(parents=True, exist_ok=True);
    packages_str = str(self.packages_dir);
    if packages_str not in sys.path {
        sys.path.insert(0, packages_str);
    }
}

impl DependencyInstaller._run_pip(args: list[str]) -> tuple[int, str, str] {
    import subprocess;
    import sys;
    cmd = [sys.executable, "-m", "pip"] + args;
    if self.verbose {
        print(f"Running: {' '.join(cmd)}");
    }
    try {
        result = subprocess.run(cmd, capture_output=True, text=True);
        return (result.returncode, result.stdout, result.stderr);
    } except Exception as e {
        return (1, "", str(e));
    }
}

impl DependencyInstaller.install_all(include_dev: bool = False) -> bool {
    import sys;
    self.ensure_packages_dir();
    all_success = True;
    for (name, version) in self.config.dependencies.items() {
        if not self.install_package(name, version) {
            all_success = False;
        }
    }
    if include_dev {
        for (name, version) in self.config.dev_dependencies.items() {
            if not self.install_package(name, version) {
                all_success = False;
            }
        }
    }
    for (name, git_info) in self.config.git_dependencies.items() {
        if isinstance(git_info, dict) {
            git_url = git_info.get("git", "");
            branch = git_info.get("branch", "");
            if not self.install_git_package(name, git_url, branch) {
                all_success = False;
            }
        }
    }
    return all_success;
}

"""Remove old package files and metadata to prevent version conflicts.

When using pip install --target, old versions can accumulate. This function
removes all traces of a package before reinstalling to ensure a clean state.
"""
impl DependencyInstaller._cleanup_old_package(name: str) -> None {
    # Temporarily disable verbose to avoid duplicate messages
    old_verbose = self.verbose;
    self.verbose = False;
    self.uninstall_package(name);
    self.verbose = old_verbose;
}

impl DependencyInstaller.install_package(name: str, version: str = "") -> bool {
    import sys;
    self.ensure_packages_dir();
    # Clean up old package files before installing to prevent version conflicts
    self._cleanup_old_package(name);
    if version {
        if version.startswith(("=", ">", "<", "~", "!")) {
            spec = f"{name}{version}";
        } else {
            spec = f"{name}=={version}";
        }
    } else {
        spec = name;
    }
    print(f"Installing {spec}...");
    (returncode, stdout, stderr) = self._run_pip(
        ["install", "--target", str(self.packages_dir), "--upgrade", spec]
    );
    if returncode == 0 {
        print(f"  {name} installed successfully");
        return True;
    } else {
        print(f"  Failed to install {name}: {stderr}", file=sys.stderr);
        return False;
    }
}

impl DependencyInstaller.install_git_package(
    name: str, git_url: str, branch: str = ""
) -> bool {
    import sys;
    self.ensure_packages_dir();
    # Clean up old package files before installing to prevent version conflicts
    self._cleanup_old_package(name);
    if branch {
        spec = f"git+{git_url}@{branch}";
    } else {
        spec = f"git+{git_url}";
    }
    print(f"Installing {name} from git...");
    (returncode, stdout, stderr) = self._run_pip(
        ["install", "--target", str(self.packages_dir), "--upgrade", spec]
    );
    if returncode == 0 {
        print(f"  {name} installed successfully from git");
        return True;
    } else {
        print(f"  Failed to install {name} from git: {stderr}", file=sys.stderr);
        return False;
    }
}

impl DependencyInstaller.uninstall_package(name: str) -> bool {
    import shutil;
    import sys;
    import csv;
    if not self.packages_dir or not self.packages_dir.exists() {
        return False;
    }
    # Find the .dist-info directory (preferred) or .egg-info (fallback)
    normalized_name = name.lower().replace("-", "_");
    dist_info_dir = None;
    egg_info_dir = None;
    for item in self.packages_dir.iterdir() {
        if item.is_dir() {
            pkg_name = item.name.lower().rsplit("-", 2)[0].replace("-", "_");
            if pkg_name == normalized_name {
                if item.name.lower().endswith(".dist-info") {
                    dist_info_dir = item;
                } elif item.name.lower().endswith(".egg-info") {
                    egg_info_dir = item;
                }
            }
        }
    }
    # Handle .egg-info with simple removal (no RECORD reading needed)
    if egg_info_dir {
        print(f"Uninstalling {name}...");
        removed = 0;
        # Remove egg-info directory
        try {
            if egg_info_dir.exists() {
                shutil.rmtree(egg_info_dir);
                removed += 1;
            }
        } except Exception as e {
            print(f"  Failed to remove {egg_info_dir.name}: {e}", file=sys.stderr);
        }
        if removed > 0 {
            print(f"  {egg_info_dir.name} uninstalled successfully ({removed} items)");
        }
        if not dist_info_dir {
            return True;
        }
    }
    # Handle .dist-info with RECORD-based removal (standard)
    metadata_dir = dist_info_dir;
    if not metadata_dir {
        return False;
    }
    record_file = metadata_dir / "RECORD";
    if not record_file.exists() {
        return False;
    }
    print(f"Uninstalling {name}...");
    # Collect all paths from RECORD
    all_paths = [];
    try {
        with open(record_file, 'r', encoding='utf-8') as f {
            reader = csv.reader(f);
            for row in reader {
                if not row or not row[0] {
                    continue;
                }

                file_path = row[0];

                # pip --target quirk: paths starting with ../ may need adjustment
                while file_path.startswith("../") {
                    # Try as-is first
                    path = (self.packages_dir / file_path).resolve();
                    if not path.exists() {
                        file_path = file_path[3:];
                    }
                }
                path = (self.packages_dir / file_path).resolve();

                # Skip if doesn't exist or is the metadata dir itself
                if not path.exists() or path.resolve() == metadata_dir.resolve() {
                    continue;
                }

                all_paths.append(path);
            }
        }
    } except Exception as e {
        print(f"  Failed to read RECORD: {e}", file=sys.stderr);
        return False;
    }
    removed = 0;
    # Delete everything in RECORD and track parent directories
    parents = set();
    for path in all_paths {
        try {
            if not path.exists() {
                continue;
            }
            if path.is_dir() {
                shutil.rmtree(path);
                removed += 1;
                parent = path.parent;
                while parent != self.packages_dir and parent.exists() {
                    parents.add(parent);
                    parent = parent.parent;
                }
            } elif path.is_file() or path.is_symlink() {
                path.unlink();
                removed += 1;
                # Track parent directories only for files (not for dirs removed by rmtree)
                parent = path.parent;
                while parent != self.packages_dir and parent.exists() {
                    parents.add(parent);
                    parent = parent.parent;
                }
            }
        } except Exception as e {
            if self.verbose {
                print(f"  Failed to remove {path.name}: {e}", file=sys.stderr);
            }
        }
    }
    # Sort parents by depth (deepest first) and remove empty ones
    parent_list = [(len(p.parts), p) for p in parents];
    parent_list.sort(reverse=True);
    for (_, parent) in parent_list {
        try {
            if parent.exists() and not any(parent.iterdir()) {
                parent.rmdir();
                removed += 1;
            }
        } except Exception { }
    }
    # Remove dist-info or egg-info directory
    try {
        if metadata_dir.exists() {
            shutil.rmtree(metadata_dir);
            removed += 1;
        }
    } except Exception as e {
        print(f"  Failed to remove {metadata_dir.name}: {e}", file=sys.stderr);
    }
    print(f"  {name} uninstalled successfully ({removed} items)");
    return True;
}

impl DependencyInstaller.is_installed(name: str) -> bool {
    if not self.packages_dir.exists() {
        return False;
    }
    normalized_name = name.lower().replace("-", "_");
    for item in self.packages_dir.iterdir() {
        item_name = item.name.lower().replace("-", "_");
        if item_name == normalized_name {
            return True;
        }
        if item_name.startswith(f"{normalized_name}_")
        and item.name.endswith(".dist-info") {
            return True;
        }
    }
    return False;
}

impl DependencyInstaller.list_installed -> list[str] {
    if not self.packages_dir.exists() {
        return [];
    }
    packages = [];
    seen: set[str] = set();
    for item in self.packages_dir.iterdir() {
        if item.name.endswith(".dist-info") {
            # Strip .dist-info suffix first, then get package name
            stem = item.name[:-10];  # len(".dist-info") == 10
            # Package name is everything before the version (first -)
            parts = stem.split("-");
            if len(parts) >= 2 {
                # Handle package names with hyphens
                # Version starts with a digit, so find the first part that starts with digit
                name_parts = [];
                for (i, part) in enumerate(parts) {
                    if part and part[0].isdigit() {
                        break;
                    }
                    name_parts.append(part);
                }
                name = "-".join(name_parts) if name_parts else parts[0];
            } else {
                name = stem;
            }
            if name and name not in seen {
                seen.add(name);
                packages.append(name);
            }
        }
    }
    return sorted(packages);
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
# Package Search Path Management Implementation
# ===============================================================================
impl add_packages_to_path(
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
    packages_dir = config.get_packages_dir();
    packages_str = str(packages_dir);
    if packages_dir.exists() and packages_str not in sys.path {
        sys.path.insert(0, packages_str);
    }
}

impl remove_packages_from_path(config: JacConfig | None = None) -> None {
    import sys;
    import from jaclang.project.config { get_config }
    if config is None {
        config = get_config();
    }
    if config is None {
        return;
    }
    packages_dir = config.get_packages_dir();
    packages_str = str(packages_dir);
    if packages_str in sys.path {
        sys.path.remove(packages_str);
    }
}

impl is_packages_in_path(config: JacConfig | None = None) -> bool {
    import sys;
    import from jaclang.project.config { get_config }
    if config is None {
        config = get_config();
    }
    if config is None {
        return False;
    }
    packages_dir = config.get_packages_dir();
    return str(packages_dir) in sys.path;
}
