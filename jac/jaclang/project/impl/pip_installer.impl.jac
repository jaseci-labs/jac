"""Implementation of pip-style editable installer for Jac projects."""

import subprocess;
import sys;
import from pathlib { Path }
import from jaclang.project.dependencies { DependencyInstaller, get_venv_site_packages }
import from jaclang.cli.console { console }

# ===============================================================================
# JacPipInstaller Implementation
# ===============================================================================
impl JacPipInstaller.postinit -> None {
    if not self.project_path.is_absolute() {
        self.project_path = self.project_path.resolve();
    }
}

impl JacPipInstaller.install_editable(
    deps: bool = True, include_dev: bool = False, extras: list[str] = []
) -> bool {
    # If only installing dev/optional dependencies (not full editable install)
    if not deps and (include_dev or extras) {
        return DependencyInstaller(config=self.config, verbose=self.verbose).install_all(
            deps=False, include_dev=include_dev, extras=extras
        );
    }
    # Full editable install (with optional dev/extras)
    return self._setup_editable_install();
}

impl JacPipInstaller._setup_editable_install -> bool {
    # Native editable install without generating pyproject.toml.
    # Creates a .pth file in site-packages to make the package importable
    # and a .dist-info directory for metadata and entry points.
    cfg = self.config;
    dep_installer = DependencyInstaller(config=cfg, verbose=self.verbose);
    dep_installer.ensure_venv();
    # Get site-packages directory
    site_packages = get_venv_site_packages(cfg.get_venv_dir());
    if not site_packages.exists() {
        console.print(f"[red]Site-packages directory not found: {site_packages}[/red]");
        return False;
    }
    try {
        # Create .pth file to make project importable
        self._create_pth_file(site_packages);

        # Create .dist-info directory with metadata and entry points
        self._create_dist_info(site_packages);

        # Report success
        jac_eps = cfg._raw_data.get("project", {}).get("entry-points", {}).get(
            "jac", {}
        );
        if jac_eps {
            console.print(f"Registered {len(jac_eps)} Jac plugin entry point(s)");
        }
        if self.verbose {
            console.print(f"Editable install complete for {cfg.project.name}");
        }
        return True;
    } except Exception as e {
        console.print(f"[red]Editable install failed: {e}[/red]");
        if self.verbose {
            import traceback;
            traceback.print_exc();
        }
        return False;
    }
}

impl JacPipInstaller._create_pth_file(site_packages: Path) -> None {
    # Create a .pth file in site-packages pointing to the project directory.
    # This makes the project package directly importable without installation.
    pkg_name = self.config.project.name.replace("-", "_");
    pth_file = site_packages / f"__{pkg_name}__.pth";
    if self.verbose {
        console.print(f"Creating .pth file: {pth_file}");
    }
    with open(pth_file, "w") as f {
        f.write(f"{self.project_path}\n");
    }
}

impl JacPipInstaller._create_dist_info(site_packages: Path) -> None {
    # Create a .dist-info directory with metadata for the editable install.
    # This includes METADATA, RECORD, entry_points.txt, and other required files.
    import email.generator;
    import email.message;
    import hashlib;
    cfg = self.config;
    pkg_name = cfg.project.name.replace("-", "_");
    dist_info_name = f"{pkg_name}-{cfg.project.version}.dist-info";
    dist_info_dir = site_packages / dist_info_name;
    if dist_info_dir.exists() {
        import shutil;
        shutil.rmtree(dist_info_dir);
        if self.verbose {
            console.print(f"Removed existing dist-info: {dist_info_dir}");
        }
    }
    dist_info_dir.mkdir(parents=True, exist_ok=True);
    if self.verbose {
        console.print(f"Creating dist-info directory: {dist_info_dir}");
    }
    # --- METADATA file ---
    metadata = email.message.EmailMessage();
    metadata["Metadata-Version"] = "2.1";
    metadata["Name"] = cfg.project.name;
    metadata["Version"] = cfg.project.version;
    if cfg.project.description {
        metadata["Summary"] = cfg.project.description;
    }
    if cfg.project.license {
        metadata["License"] = cfg.project.license;
    }
    if cfg.project.authors {
        for author in cfg.project.authors {
            metadata["Author"] = author;
            break;  # Use first author
        }
    }
    if cfg.project.keywords {
        for kw in cfg.project.keywords {
            metadata["Keywords"] = kw;
        }
    }
    metadata["Requires-Python"] = ">=3.11";
    # Add dependencies
    if cfg.dependencies {
        for (name, version) in cfg.dependencies.items() {
            if not version or version == ">=0.0.0" {
                metadata["Requires-Dist"] = name;
            } elif version.startswith(("=", ">", "<", "~", "!")) {
                metadata["Requires-Dist"] = f"{name}{version}";
            } else {
                metadata["Requires-Dist"] = f"{name}=={version}";
            }
        }
    }
    # Add optional dependencies
    if cfg.dev_dependencies {
        for (name, version) in cfg.dev_dependencies.items() {
            if not version or version == ">=0.0.0" {
                metadata["Provides-Extra"] = "dev";
                metadata["Requires-Dist"] = f"{name}; extra == \"dev\"";
            } elif version.startswith(("=", ">", "<", "~", "!")) {
                metadata["Provides-Extra"] = "dev";
                metadata["Requires-Dist"] = f"{name}{version}; extra == \"dev\"";
            } else {
                metadata["Provides-Extra"] = "dev";
                metadata["Requires-Dist"] = f"{name}=={version}; extra == \"dev\"";
            }
        }
    }
    if cfg.optional_dependencies {
        for (group, odeps) in cfg.optional_dependencies.items() {
            for (name, version) in odeps.items() {
                metadata["Provides-Extra"] = group;
                if not version or version == ">=0.0.0" {
                    metadata["Requires-Dist"] = f"{name}; extra == \"{group}\"";
                } elif version.startswith(("=", ">", "<", "~", "!")) {
                    metadata["Requires-Dist"] = f"{name}{version}; extra == \"{group}\"";
                } else {
                    metadata["Requires-Dist"] = f"{name}=={version}; extra == \"{group}\"";
                }
            }
        }
    }
    metadata_file = dist_info_dir / "METADATA";
    with open(metadata_file, "w") as f {
        gen = email.generator.Generator(f, mangle_from_=False, maxheaderlen=0);
        gen.flatten(metadata);
    }
    # --- INSTALLER file ---
    installer_file = dist_info_dir / "INSTALLER";
    with open(installer_file, "w") as f {
        f.write("jac\n");
    }
    # --- top_level.txt file ---
    top_level_file = dist_info_dir / "top_level.txt";
    with open(top_level_file, "w") as f {
        f.write(f"{pkg_name}\n");
    }
    # --- entry_points.txt file ---
    jac_eps = cfg._raw_data.get("project", {}).get("entry-points", {}).get("jac", {});
    if jac_eps {
        entry_points_file = dist_info_dir / "entry_points.txt";
        with open(entry_points_file, "w") as f {
            f.write("[jac]\n");
            for (ep_name, ep_value) in jac_eps.items() {
                f.write(f"{ep_name} = {ep_value}\n");
            }
        }
    }
    # --- RECORD file ---
    # The RECORD file lists all installed files with their hashes
    pth_file = site_packages / f"__{pkg_name}__.pth";
    record_file = dist_info_dir / "RECORD";
    record_entries: list[str] = [];
    def _hash_file(path: Path) -> str {
        hasher = hashlib.sha256();
        with open(path, "rb") as f {
            hasher.update(f.read());
        }
        return f"sha256={hasher.hexdigest()}";
    }
    # Add .pth file to RECORD
    if pth_file.exists() {
        pth_hash = _hash_file(pth_file);
        pth_size = pth_file.stat().st_size;
        pth_rel = pth_file.relative_to(site_packages);
        record_entries.append(f"{pth_rel},{pth_hash},{pth_size}");
    }
    # Add dist-info files to RECORD
    for item in dist_info_dir.iterdir() {
        if item.is_file() and item.name != "RECORD" {
            file_hash = _hash_file(item);
            file_size = item.stat().st_size;
            file_rel = item.relative_to(site_packages);
            record_entries.append(f"{file_rel},{file_hash},{file_size}");
        }
    }
    # RECORD file itself has no hash
    record_rel = record_file.relative_to(site_packages);
    record_entries.append(f"{record_rel},,");
    with open(record_file, "w") as f {
        f.write("\n".join(record_entries) + "\n");
    }
}

# ===============================================================================
# Standalone Functions
# ===============================================================================
"""Check if a package is installed in the current environment."""
impl is_package_installed(name: str) -> bool {
    import importlib.util;
    return importlib.util.find_spec(name) is not None;
}
