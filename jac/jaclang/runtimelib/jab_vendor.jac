import json;
import logging;
import os;
import shutil;
import subprocess;
import sys;
import from pathlib { Path }

glob logger = logging.getLogger(__name__);

glob VENDOR_DIR_REL: str = "_vendor",
     WHEELS_SUBDIR: str = "wheels",
     SITE_SUBDIR: str = "site",
     VENDOR_MANIFEST: str = "VENDOR.json",
     SITE_READY_MARKER: str = ".site-ready";


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
    return wd.is_dir() and any(wd.glob("*.whl"));
}


def _pip(args: list[str]) -> tuple[int, str] {
    result = subprocess.run(
        [sys.executable, "-m", "pip"] + args, capture_output=True, text=True
    );
    return (result.returncode, (result.stderr or result.stdout or "").strip());
}


def download_wheels(
    specs: list[str], dest: Path, platform_tag: str = "", python_version: str = ""
) -> tuple[bool, str] {
    if not specs {
        return (True, "");
    }
    dest.mkdir(parents=True, exist_ok=True);
    args = ["download", "--only-binary=:all:", "--dest", str(dest)];
    if platform_tag {
        args = args + ["--platform", platform_tag];
    }
    if python_version {
        args = args + ["--python-version", python_version];
    }
    (rc, out) = _pip(args + specs);
    if rc != 0 {
        if platform_tag or python_version {
            return (False, out);
        }
        return _build_wheels_native(specs, dest, out);
    }
    return (True, "");
}


def _build_wheels_native(
    specs: list[str], dest: Path, download_err: str
) -> tuple[bool, str] {
    (rc, out) = _pip(["wheel", "--wheel-dir", str(dest)] + specs);
    if rc != 0 {
        return (False, f"{download_err}\n{out}");
    }
    import re;
    built = sorted(set(re.findall(r"Building wheel for ([A-Za-z0-9_.\-]+)", out)));
    if built {
        logger.info(
            f"Built wheel(s) from source: {', '.join(built)}; they target "
            "the vendoring interpreter and architecture."
        );
    }
    return (True, "");
}


def write_vendor_manifest(
    img_root: Path, specs: list[str], python_tag: str = "", platform_tag: str = ""
) {
    vd = vendor_dir(img_root);
    vd.mkdir(parents=True, exist_ok=True);
    wd = wheels_dir(img_root);
    wheels = sorted([p.name for p in wd.glob("*.whl")]) if wd.is_dir() else [];
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
        ) + "\n",
        encoding="utf-8"
    );
}


def _install_offline(wheels: Path, site: Path) {
    if site.is_dir() {
        return;
    }
    whl_files = sorted([str(p) for p in wheels.glob("*.whl")]);
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
