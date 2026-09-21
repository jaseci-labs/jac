import json;
import logging;
import os;
import platform;
import re;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob logger = logging.getLogger(__name__);

glob VENDOR_DIR_REL: str = "_vendor",
     WHEELS_SUBDIR: str = "wheels",
     SITE_SUBDIR: str = "site",
     VENDOR_MANIFEST: str = "VENDOR.json",
     SITE_READY_MARKER: str = ".site-ready";

glob MAX_SOURCE_ROUNDS: int = 10;

glob MANYLINUX_ALIASES: dict[tuple[int, int], str] = {
         (2, 5): "manylinux1",
         (2, 12): "manylinux2010",
         (2, 17): "manylinux2014"
     };

glob _NO_MATCH_RE = re.compile(
         r"^(?:ERROR: )?No matching distribution found for (.+?)\s*$", re.M
     ),
     _NO_DIST_HEADER: str = "no matching distributions available for your environment:";


def manylinux_tags(arch: str, glibc: tuple[int, int]) -> list[str] {
    (major, minor) = glibc;
    oldest = 5 if arch in ("x86_64", "i686") else 17;
    tags: list[str] = [];
    for m in range(minor, oldest - 1, -1) {
        tags.append(f"manylinux_{major}_{m}_{arch}");
        alias = MANYLINUX_ALIASES.get((major, m));
        if alias {
            tags.append(f"{alias}_{arch}");
        }
    }
    return tags;
}


obj WheelTarget {
    has arch: str,
        python_version: str,
        glibc: tuple[int, int];

    def platform_tag -> str {
        return f"manylinux_{self.glibc[0]}_{self.glibc[1]}_{self.arch}";
    }

    def host_build_compatible -> bool {
        if sys.platform != "linux" or platform.machine() != self.arch {
            return False;
        }
        (libc, version) = platform.libc_ver();
        if libc != "glibc" or not re.fullmatch(r"\d+\.\d+", version) {
            return False;
        }
        (major, minor) = version.split(".");
        return (int(major), int(minor)) <= self.glibc;
    }

    def platform_tags -> list[str] {
        return manylinux_tags(self.arch, self.glibc);
    }

    def pip_args(allow_host_build: bool = False) -> list[str] {
        args = ["--python-version", self.python_version, "--implementation", "cp"];
        for tag in self.platform_tags() {
            args = args + ["--platform", tag];
        }

        if allow_host_build and self.host_build_compatible() {
            args = args + ["--platform", f"linux_{self.arch}"];
        }
        return args;
    }

    def describe -> str {
        return f"{self.platform_tag()} on python {self.python_version}";
    }
}


obj WheelDownloadResult {
    has ok: bool,
        missing: list[str] = [],
        detail: str = "";
}


def vendor_dir(img_root: Path) -> Path {
    return Path(img_root) / VENDOR_DIR_REL;
}


def wheels_dir(img_root: Path) -> Path {
    return vendor_dir(img_root) / WHEELS_SUBDIR;
}


def site_dir(img_root: Path) -> Path {
    return vendor_dir(img_root) / SITE_SUBDIR;
}


def has_vendored(img_root: Path) -> bool {
    wd = wheels_dir(img_root);
    return wd.is_dir() and any(wd.`glob("*.whl"));
}


def _pip(args: list[str]) -> tuple[int, str] {
    import from jaclang.project.pyvenv { pip_command, pip_python, pip_env }
    result = subprocess.run(
        pip_command(pip_python(), args), capture_output=True, text=True, env=pip_env()
    );

    return (
        result.returncode,
        ((result.stdout or "") + "\n" + (result.stderr or "")).strip()
    );
}


def download_wheels(
    specs: list[str], dest: Path, target: (WheelTarget | None) = None
) -> WheelDownloadResult {
    if not specs {
        return WheelDownloadResult(ok=True);
    }
    dest.mkdir(parents=True, exist_ok=True);
    with tempfile.TemporaryDirectory(prefix="jac-source-wheels-") as tmp {
        return _resolve_wheels(specs, dest, target, Path(tmp));
    }
}


def _resolve_wheels(
    specs: list[str], dest: Path, target: (WheelTarget | None), build_dir: Path
) -> WheelDownloadResult {
    flags = ["download", "--only-binary=:all:", "--dest", str(dest)];
    built: dict[str, list[Path]] = {};
    for round in range(MAX_SOURCE_ROUNDS + 1) {
        links = ["--find-links", str(build_dir)] if built else [];
        pins = target.pip_args(allow_host_build=bool(built))
            if target is not None
            else [];
        (rc, out) = _pip(flags + pins + links + specs);
        if rc == 0 {
            return WheelDownloadResult(ok=True);
        }
        missing = _missing_requirements(out);
        if not missing {
            return WheelDownloadResult(ok=False, detail=out);
        }
        unfit = [
            name
            for name in missing
            if name in built
        ];
        if unfit {
            return WheelDownloadResult(
                ok=False, missing=unfit, detail=_reject_unfit(unfit, built, target)
            );
        }
        if round == MAX_SOURCE_ROUNDS {
            return WheelDownloadResult(
                ok=False,
                missing=list(missing.keys()),
                detail=f"Wheel vendoring stopped after {round} source-build rounds; "
                f"still missing: {', '.join(missing.keys())}"
            );
        }
        logger.info(
            f"Wheel vendoring source-build round {round + 1}: {', '.join(
                missing.keys()
            )}"
        );
        (produced, err) = _build_from_source(missing, build_dir);
        if err {
            return WheelDownloadResult(
                ok=False, missing=list(missing.keys()), detail=f"{out}\n{err}"
            );
        }
        for (name, files) in produced.items() {
            built[name] = files;
        }
    }
    return WheelDownloadResult(
        ok=False, detail="Wheel vendoring exhausted source-build rounds"
    );
}


def _missing_requirements(out: str) -> dict[str, list[str]] {
    found: dict[str, list[str]] = {};
    for m in _NO_MATCH_RE.finditer(out) {
        req = m.group(1).strip();
        found[_project_name(req)] = [req];
    }
    lines = out.splitlines();
    for (i, line) in enumerate(lines) {
        if not line.rstrip().endswith(_NO_DIST_HEADER) {
            continue;
        }
        for follow in lines[i + 1:] {
            if not follow.startswith(" ") or not follow.strip() {
                break;
            }
            name = follow.strip();
            found.setdefault(_project_name(name), []);
        }
    }

    for line in lines {
        req = "";
        if " depends on " in line {
            req = line.split(" depends on ", 1)[1].strip();
        } elif line.strip().startswith("The user requested ") {
            req = line.strip().removeprefix("The user requested ");
        }
        req = re.sub(r" and (?=[<>=!~])", ",", req);
        name = _project_name(req);
        if name in found and req not in found[name] {
            found[name].append(req);
        }
    }
    for (name, reqs) in found.items() {
        if not reqs {
            reqs.append(name);
        }
    }
    return found;
}


def _project_name(req: str) -> str {
    head = re.split(r"[\s<>=!~;\[(@]", req.strip(), maxsplit=1)[0];
    return re.sub(r"[-_.]+", "-", head).lower();
}


def _build_from_source(
    missing: dict[str, list[str]], dest: Path
) -> tuple[dict[str, list[Path]], str] {
    produced: dict[str, list[Path]] = {};
    for (name, reqs) in missing.items() {
        before = set(dest.`glob("*.whl"));
        flags = [
            "wheel",
            "--no-deps",
            "--wheel-dir",
            str(dest),
            "--no-cache-dir",
            "--no-binary",
            name
        ];
        (rc, out) = _pip(flags + reqs);

        if rc != 0 and len(reqs) > 1 {
            errors: list[str] = [];
            for req in reqs {
                (candidate_rc, candidate_out) = _pip(flags + [req]);
                if candidate_rc != 0 {
                    errors.append(candidate_out);
                }
            }
            rc = 1 if len(errors) == len(reqs) else 0;
            out = "\n".join(errors);
        }
        if rc != 0 {
            return ({}, out);
        }
        produced[name] = sorted(set(dest.`glob("*.whl")) - before);
        logger.info(
            f"No published wheel for {', '.join(reqs)}; built "
            f"{', '.join([p.name for p in produced[name]]) or 'nothing'} on this host."
        );
    }
    return (produced, "");
}


def _reject_unfit(
    unfit: list[str], built: dict[str, list[Path]], target: (WheelTarget | None)
) -> str {
    where = target.describe() if target is not None else "this host";
    reasons: list[str] = [];
    for name in unfit {
        files = built.get(name, []);
        for path in files {
            path.unlink(missing_ok=True);
        }
        made = ", ".join([p.name for p in files]) or "no wheel at all";
        reasons.append(
            f"{name}: no published wheel for {where}, and building it on this "
            f"host produced {made}, which does not fit that target"
        );
    }
    return "\n".join(reasons);
}


def write_vendor_manifest(
    img_root: Path, specs: list[str], python_tag: str = "", platform_tag: str = ""
) {
    vd = vendor_dir(img_root);
    vd.mkdir(parents=True, exist_ok=True);
    wd = wheels_dir(img_root);
    wheels = sorted([p.name for p in wd.`glob("*.whl")]) if wd.is_dir() else [];
    (vd / VENDOR_MANIFEST).write_text(
        json.dumps(
            {
                "format": 1,
                "specs": sorted(specs),
                "wheels": wheels,
                "python_tag": python_tag,
                "platform_tag": platform_tag
            },
            sort_keys=True,
            indent=1
        )
            + "\n",
        encoding="utf-8"
    );
}


def _install_offline(wheels: Path, site: Path) {
    if site.is_dir() {
        return;
    }
    whl_files = sorted([str(p) for p in wheels.`glob("*.whl")]);
    if not whl_files {
        return;
    }
    tmp = site.with_suffix(f".{os.getpid()}.tmp");
    shutil.rmtree(tmp, ignore_errors=True);
    tmp.mkdir(parents=True, exist_ok=True);
    (rc, out) = _pip(
        ["install", "--no-index", "--no-deps", "--target", str(tmp)] + whl_files
    );
    if rc != 0 {
        shutil.rmtree(tmp, ignore_errors=True);
        raise RuntimeError(
            f"fat jab: offline install of vendored wheels failed: {out}"
        );
    }
    try {
        tmp.rename(site);
    } except OSError as e {
        shutil.rmtree(tmp, ignore_errors=True);
        if not site.is_dir() {
            raise RuntimeError(
                f"fat jab: could not activate vendored site {site}: {e}"
            );
        }
    }
}


def activate_vendored(img_root: Path) -> Path | None {
    if not has_vendored(img_root) {
        return None;
    }
    site = site_dir(img_root);
    marker = vendor_dir(img_root) / SITE_READY_MARKER;
    if not marker.is_file() {
        _install_offline(wheels_dir(img_root), site);
        marker.write_text("", encoding="utf-8");
    }
    site_str = str(site);
    if site_str not in sys.path {
        sys.path.insert(0, site_str);
        import importlib;
        importlib.invalidate_caches();
    }
    return site;
}
