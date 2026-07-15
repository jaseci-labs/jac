"""Fat-jab dependency vendoring (issue #7465).

A *fat jab* packs its Python dependency closure as wheels so the bundle is
self-contained the way a Spring Boot fat jar nests every dependency jar: copy
one file to any machine with a compatible jac runtime and it runs, with no PyPI
and no `jac install` at startup. The wheels live under `_vendor/wheels/`, a
sibling of `_precompiled/`, so the sealed manifest's hash-checked module tree is
left untouched. Because they ride inside the tarball, the wheels are covered by
the jab's existing sha256 content addressing for free: bump a dep, get a new
digest, get a new cache dir, with no stale-dep aliasing.

Two halves, build-time and run-time, share only the layout constants below:

- Build (`jac build --fat`): `download_wheels` resolves the closure into
  `_vendor/wheels/` via `pip download`. Cross-platform resolution is a pip
  concern: it honors `PIP_INDEX_URL` / `PIP_FIND_LINKS` / `PIP_NO_INDEX` and,
  when a target triple is chosen, `--platform` / `--python-version`.
- Run (materialize): `activate_vendored` installs the wheels offline into a
  cache-scoped `_vendor/site/` (once per content-addressed image, guarded by a
  ready-marker) and puts it on `sys.path`, so the app imports its deps with no
  network. `--no-index` makes the install fail closed rather than reach PyPI.

Kept lightweight (stdlib + pathlib only) so it is importable on the materialize
path alongside `jab.jac`.
"""

import json;
import logging;
import os;
import shutil;
import subprocess;
import sys;
import from pathlib { Path }

glob VENDOR_DIR_REL: str = "_vendor";
glob WHEELS_SUBDIR: str = "wheels";
glob SITE_SUBDIR: str = "site";
glob VENDOR_MANIFEST: str = "VENDOR.json";
glob SITE_READY_MARKER: str = ".site-ready";


def vendor_dir(img_root: Path) -> Path {
    return Path(img_root) / VENDOR_DIR_REL;
}


def wheels_dir(img_root: Path) -> Path {
    return vendor_dir(img_root) / WHEELS_SUBDIR;
}


def site_dir(img_root: Path) -> Path {
    return vendor_dir(img_root) / SITE_SUBDIR;
}


"""True when `img_root` carries a vendored wheel closure."""
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


"""Download `specs` and their transitive closure as wheels into `dest`.

`--only-binary=:all:` guarantees every vendored artifact is an installable wheel
(never an sdist that would need a build toolchain offline), so the resulting
bundle fails closed at build time rather than shipping something that cannot
materialize. When `platform_tag` is given the closure is resolved for that target
instead of the build host (cross-platform build).
"""
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
        return (False, out);
    }
    return (True, "");
}


"""Record what was vendored: a plain sidecar (not the sealed manifest) that lets
tooling and the deploy bootstrap see a fat jab without unpacking."""
def write_vendor_manifest(
    img_root: Path, specs: list[str], python_tag: str = "", platform_tag: str = ""
) {
    vd = vendor_dir(img_root);
    vd.mkdir(parents=True, exist_ok=True);
    wheels = sorted([p.name for p in wheels_dir(img_root).glob("*.whl")]);
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


"""Install every vendored wheel into `site` with no network access.

`--no-deps` is safe because the closure is already complete (build-time
`pip download` pulled every transitive dep), and it keeps the install
deterministic and offline. Writes to a pid-scoped temp dir and renames it into
place so a crashed install never leaves a half-populated `site`.
"""
def _install_offline(wheels: Path, site: Path) -> bool {
    whl_files = sorted([str(p) for p in wheels.glob("*.whl")]);
    if not whl_files {
        return False;
    }
    tmp = site.with_suffix(f".{os.getpid()}.tmp");
    shutil.rmtree(tmp, ignore_errors=True);
    tmp.mkdir(parents=True, exist_ok=True);
    (rc, out) = _pip(
        ["install", "--no-index", "--no-deps", "--target", str(tmp)] + whl_files
    );
    if rc != 0 {
        shutil.rmtree(tmp, ignore_errors=True);
        logging.getLogger(__name__).warning(
            f"fat jab: offline install of vendored wheels failed: {out}"
        );
        return False;
    }
    shutil.rmtree(site, ignore_errors=True);
    tmp.rename(site);
    return True;
}


"""If `img_root` is a fat jab, ensure its wheels are installed and on `sys.path`;
return the vendored site dir (or None when there is nothing to do).

Idempotent: the offline install runs once per content-addressed image, guarded
by a ready-marker, so repeated runs only re-prepend `sys.path`.
"""
def activate_vendored(img_root: Path) -> Path | None {
    if not has_vendored(img_root) {
        return None;
    }
    site = site_dir(img_root);
    marker = vendor_dir(img_root) / SITE_READY_MARKER;
    if not marker.is_file() {
        if not _install_offline(wheels_dir(img_root), site) {
            return None;
        }
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
