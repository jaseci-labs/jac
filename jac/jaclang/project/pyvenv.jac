import re;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.cli.console { console }


def pip_command(python: str, args: list[str]) -> list[str] {
    return [python, "-m", "pip"] + args;
}


def venv_python(venv_dir: Path) -> str {
    import sys;
    if sys.platform == "win32" {
        return str(venv_dir / "Scripts" / "python.exe");
    }
    return str(venv_dir / "bin" / "python");
}


def make_pip_spec(name: str, version: str) -> str {
    if not version or version in ("*", "latest") {
        return name;
    }
    if version.startswith(("=", ">", "<", "~", "!")) {
        return f"{name}{version}";
    }
    return f"{name}=={version}";
}


def make_git_spec(git_url: str, branch: str = "") -> str {
    if branch {
        return f"git+{git_url}@{branch}";
    }
    return f"git+{git_url}";
}


def _seed_build_backend(target: Path, verbose: bool = False) {
    (rc, _, err) = run_pip(
        target, ["install", "--upgrade", "pip", "setuptools", "wheel"], verbose
    );
    if rc != 0 and verbose {
        console.print(f"Warning: could not seed build backend in venv: {err.strip()}");
    }
}


def ensure_venv(venv_dir: Path, verbose: bool = False) {
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
        _seed_build_backend(target, verbose);
    }
    if venv_dir.exists() {
        pyvenv_cfg = venv_dir / "pyvenv.cfg";
        python_path = Path(venv_python(venv_dir));
        if not pyvenv_cfg.exists() or not python_path.exists() {
            import shutil;
            if verbose {
                console.print(f"Recreating corrupted venv at {venv_dir}");
            }
            shutil.rmtree(venv_dir);
            _create_venv(venv_dir);
        }
    } else {
        if verbose {
            console.print(f"Creating venv at {venv_dir}");
        }
        venv_dir.parent.mkdir(parents=True, exist_ok=True);
        _create_venv(venv_dir);
    }

    site_packages = str(get_venv_site_packages(venv_dir));
    if site_packages not in sys.path {
        sys.path.insert(0, site_packages);
    }
}


def _venv_site(venv_dir: Path) -> Path {
    site = get_venv_site_packages(venv_dir);
    site.mkdir(parents=True, exist_ok=True);
    return site;
}


def _adjust_pip_args_for_fused_venv(venv_dir: Path, args: list[str]) -> list[str] {
    if not args {
        return args;
    }
    site = str(_venv_site(venv_dir));
    cmd = args[0];
    rest = args[1:];
    if cmd == "install" {
        if "--target" in rest or "-t" in rest or "--prefix" in rest {
            return args;
        }
        return ["install", "--target", site] + rest;
    }
    if cmd in ("list", "freeze") {
        if "--path" in rest {
            return args;
        }
        return [cmd, "--path", site] + rest;
    }
    return args;
}

def _find_venv_distribution(site: Path, name: str) -> any {
    import importlib.metadata;
    wanted = re.sub(r"[-_.]+", "-", name).lower();
    for dist in importlib.metadata.distributions(path=[str(site)]) {
        raw = dist.metadata.get("Name") or "";
        if not raw {
            raw = getattr(dist, "name", "") or "";
        }
        if re.sub(r"[-_.]+", "-", str(raw)).lower() == wanted {
            return dist;
        }
    }
    return None;
}


def _uninstall_from_venv_site(venv_dir: Path, name: str) -> tuple[int, str, str] {
    import shutil;
    site = _venv_site(venv_dir);
    dist = _find_venv_distribution(site, name);
    if dist is None {
        return (1, "", f"Package(s) not found: {name}");
    }
    removed: list[str] = [];
    files = dist.files;
    if files {
        for rel in files {
            path = Path(str(dist.locate_file(rel)));
            try {
                if path.is_file() or path.is_symlink() {
                    path.unlink();
                    removed.append(str(rel));
                }
            } except OSError {
                continue;
            }
        }
    }
    dist_path = Path(str(getattr(dist, "_path", "")));
    if str(dist_path) != "" and dist_path.exists() {
        shutil.rmtree(dist_path, ignore_errors=True);
    }
    msg = f"Successfully uninstalled {name}";
    if removed {
        msg += f" ({len(removed)} files)";
    }
    return (0, msg + "\n", "");
}


def run_pip(
    venv_dir: Path, args: list[str], verbose: bool = False
) -> tuple[int, str, str] {
    import subprocess;
    if args and args[0] == "uninstall" {
        names = [
            a
            for a in args[1:]
            if a and not a.startswith("-")
        ];
        if not names {
            return (1, "", "No packages specified for uninstall");
        }
        outs: list[str] = [];
        errs: list[str] = [];
        rc = 0;
        for name in names {
            if verbose {
                console.print(
                    f"Uninstalling {name} from {get_venv_site_packages(venv_dir)}"
                );
            }
            (code, out, err) = _uninstall_from_venv_site(venv_dir, name);
            if out {
                outs.append(out);
            }
            if err {
                errs.append(err);
            }
            if code != 0 {
                rc = code;
            }
        }
        return (rc, "".join(outs), "".join(errs));
    }
    if args and args[0] == "show" {
        names = [
            a
            for a in args[1:]
            if a and not a.startswith("-")
        ];
        site = _venv_site(venv_dir);
        chunks: list[str] = [];
        missing = False;
        for name in names {
            dist = _find_venv_distribution(site, name);
            if dist is None {
                missing = True;
                continue;
            }
            meta = dist.metadata;
            lines = [
                f"Name: {meta.get('Name', name)}",
                f"Version: {meta.get('Version', '')}",
                f"Summary: {meta.get('Summary', '')}",
                f"Home-page: {meta.get('Home-page', '')}",
                f"Author: {meta.get('Author', '')}",
                f"Location: {site}",
                ""
            ];
            chunks.append("\n".join(lines));
        }
        if not chunks {
            return (1, "", "WARNING: Package(s) not found: " + ", ".join(names));
        }
        return (1 if missing else 0, "\n".join(chunks), "");
    }
    adjusted = _adjust_pip_args_for_fused_venv(venv_dir, args);
    cmd = pip_command(venv_python(venv_dir), adjusted);
    if verbose {
        console.print(f"Running: {' '.join(cmd)}");
    }
    try {
        result = subprocess.run(cmd, capture_output=True, text=True);
        return (result.returncode, result.stdout, result.stderr);
    } except Exception as e {
        return (1, "", str(e));
    }
}


def _spec_base_name(spec: str) -> str {
    m = re.match(r"^([A-Za-z0-9._-]+)\s*(?:[<>=!~@;\[]|$)", spec.strip());
    return m.group(1).lower() if m else "";
}


def _extract_terminal_error(stderr: str) -> str {
    lines = [
        ln.strip()
        for ln in stderr.splitlines()
        if ln.strip()
    ];
    if not lines {
        return "";
    }
    for ln in reversed(lines) {
        if ln.startswith("ERROR: ") {
            return ln[7:].strip();
        }
        if re.match(r"^[\w.]+(Error|Exception|Unavailable|NotFound):", ln) {
            return ln;
        }
    }
    return lines[-1];
}


def _identify_failed_package(specs: list[str], stderr: str) -> str | None {
    low = stderr.lower();
    named: list[str] = [];
    for s in specs {
        name = _spec_base_name(s);
        if name and name in low {
            named.append(s);
        }
    }
    if len(named) == 1 {
        return named[0];
    }
    if len(specs) == 1 {
        return specs[0];
    }
    return None;
}


def summarize_pip_failure(specs: list[str], stderr: str) -> tuple[str | None, str] {
    return (_identify_failed_package(specs, stderr), _extract_terminal_error(stderr));
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
    candidates.sort(key=lambda (p) { p.parent.name; }, reverse=True);
    return candidates[0];
}


def get_venv_site_packages(venv_dir: Path) -> Path {
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


def add_venv_to_path(config: JacConfig | None = None) -> None {
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


def remove_venv_from_path(config: JacConfig | None = None) -> None {
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


def is_venv_in_path(config: JacConfig | None = None) -> bool {
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
