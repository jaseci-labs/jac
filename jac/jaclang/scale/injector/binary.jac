import io;
import os;
import json;
import shutil;
import hashlib;
import platform;
import subprocess;
import tarfile;
import tempfile;
import from pathlib { Path }
import from urllib.request { urlopen }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }

glob BINARY_ARCNAME: str = "bin/jac",
     OVERLAY_SUBDIR: str = "jaclang-src",
     _HTTP_TIMEOUT: int = 60,
     _SUBPROCESS_TIMEOUT: int = 300,
     _JASECI_REPO: str = "https://github.com/jaseci-labs/jaseci",
     _SKIP_DIRS: set[str] = {"__pycache__", ".git", "node_modules", ".jac"};


def host_arch -> str {
    m = platform.machine();
    return "aarch64" if m in ("arm64", "aarch64") else m;
}


def node_arch -> str {
    # The pods run linux; the asset arch must match the *node*, not necessarily
    # the deploy host. Default to the host arch (the common single-machine and
    # homogeneous-cluster case) and let JAC_NODE_ARCH override for cross-arch
    # deploys (e.g. an x86_64 laptop deploying to aarch64 nodes).
    return os.environ.get("JAC_NODE_ARCH", "") or host_arch();
}


def _http_get_bytes(url: str) -> bytes {
    # timeout bounds inactivity (no bytes for _HTTP_TIMEOUT s), not total
    # download time, so a slow but progressing large-binary fetch is fine while a
    # stalled connection fails fast instead of hanging the deploy forever.
    resp = urlopen(url, timeout=_HTTP_TIMEOUT);
    try {
        return bytes(resp.read());
    } finally {
        resp.close();
    }
}


def download_release_binary(channel: str, arch: str) -> bytes {
    # Fetch a prebuilt, self-contained `jac` binary from jaseci-labs releases:
    #   stable -> the latest published release (jac-<ver>-linux-<arch>)
    #   dev    -> the rolling `dev` prerelease, force-moved to main HEAD on every
    #             push (jac-dev-linux-<arch>); see .github/workflows/release-dev.yml
    repo = "jaseci-labs/jaseci";
    api = (
        f"https://api.github.com/repos/{repo}/releases/tags/dev"
            if channel == "dev"
            else f"https://api.github.com/repos/{repo}/releases/latest"
    );
    meta = json.loads(_http_get_bytes(api).decode("utf-8"));

    suffix = f"-linux-{arch}";
    binary_url = "";
    checksum_url = "";
    for asset in meta.get("assets", []) {
        name = str(asset.get("name", ""));
        url = str(asset.get("browser_download_url", ""));
        if not name.startswith("jac-") {
            continue;
        }
        if name.endswith(suffix + ".sha256") {
            checksum_url = url;
        } elif name.endswith(suffix) {
            binary_url = url;
        }
    }
    if not binary_url {
        tag = "dev" if channel == "dev" else meta.get("tag_name", "latest");
        raise RuntimeError(
            f"No `jac-*{suffix}` asset on the {channel} release ({tag}). The node "
            f"arch may be unpublished; set JAC_NODE_ARCH or check "
            f"https://github.com/{repo}/releases."
        );
    }

    payload = _http_get_bytes(binary_url);
    if checksum_url {
        parts = _http_get_bytes(checksum_url).decode("utf-8").split();
        if not parts {
            raise RuntimeError(
                f"Checksum file at {checksum_url} is empty or malformed; "
                f"cannot verify the downloaded binary."
            );
        }
        want = parts[0].strip().lower();
        got = hashlib.sha256(payload).hexdigest();
        if got != want {
            raise RuntimeError(
                f"Checksum mismatch for the downloaded jac binary "
                f"(expected {want}, got {got}); refusing to ship it."
            );
        }
    }
    return payload;
}


def _clone_jac_source(repo: str, branch: str) -> tuple[Path, Path] {
    # Returns (jac_dir, tmp_root); tmp_root is the mkdtemp dir the caller must
    # clean up once it is done with the source (see cleanup_overlay_source).
    dest = Path(tempfile.mkdtemp(prefix="jac-overlay-"));
    try {
        subprocess.run(
            [
                "git",
                "clone",
                "--depth",
                "1",
                "--branch",
                branch,
                "--single-branch",
                repo,
                str(dest)
            ],
            check=True,
            timeout=_SUBPROCESS_TIMEOUT
        );
        jacdir = dest / "jac";
        if not (jacdir / "jaclang").is_dir() {
            raise RuntimeError(
                f"{repo}@{branch} has no jac/jaclang source tree to overlay."
            );
        }
        return (jacdir, dest);
    } except Exception {
        shutil.rmtree(dest, ignore_errors=True);
        raise;
    }
}


def resolve_overlay_source(
    repo: str, branch: str, jaclang_source: str, project_dir: str
) -> tuple[Path, (Path | None)] {
    # Resolve the jaclang source dir to overlay on the downloaded binary. Returns
    # (source_root, cleanup_root): source_root is the dir CONTAINING `jaclang/`
    # (the repo's `jac/` dir); cleanup_root is a temp clone to delete after use,
    # or None when source_root is a local checkout that must be kept. Precedence:
    #   explicit repo/branch  ->  local jaclang_source dir if it exists  ->  main
    if repo {
        return _clone_jac_source(repo, branch or "main");
    }
    if jaclang_source {
        local = (Path(project_dir) / jaclang_source).resolve();
        if (local / "jaclang").is_dir() {
            return (local, None);
        }
    }
    return _clone_jac_source(_JASECI_REPO, "main");
}


def cleanup_overlay_source(cleanup_root: (Path | None)) {
    if cleanup_root is not None {
        shutil.rmtree(cleanup_root, ignore_errors=True);
    }
}


def precompile_overlay(binary_bytes: bytes, source_root: Path, arch: str) -> bool {
    # OPTION A: run the downloaded binary over the overlay's own
    # precompile_bytecode util to emit `jaclang/_precompiled/<pyver>/*.jir`, so
    # the pod boots without compiling. Only possible when the binary runs on this
    # host (arch match); a mismatch - or any failure - returns False so we ship
    # source only (OPTION B: the pod compiles once on boot). This is the swappable
    # cross-arch seam: a future cross-arch compiler can drop in here.
    if arch != host_arch() {
        return False;
    }
    util = source_root / "jaclang" / "utils" / "precompile_bytecode.jac";
    if not util.is_file() {
        return False;
    }
    tmpbin = source_root.parent / "jac-precompiler";
    try {
        tmpbin.write_bytes(binary_bytes);
        tmpbin.chmod(0o755);
        subprocess.run(
            [str(tmpbin), "run", str(util), str(source_root / "jaclang")],
            check=True,
            timeout=_SUBPROCESS_TIMEOUT
        );
        return True;
    } except Exception {
        return False;
    } finally {
        if tmpbin.is_file() {
            tmpbin.unlink();
        }
    }
}


def _skip(path: Path) -> bool {
    for part in path.parts {
        if part in _SKIP_DIRS {
            return True;
        }
    }
    return False;
}


def pack_binary_bytes(binary_bytes: bytes) -> bytes {
    # Tar just the self-contained `jac` binary into the toolchain layout the
    # pod's unpack init container expects. No source: the STABLE channel runs the
    # binary's own bundled jaclang as-is.
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        info = tarfile.TarInfo(name=f"{TOOLCHAIN_SUBDIR}/{BINARY_ARCNAME}");
        info.size = len(binary_bytes);
        info.mode = 0o755;
        tar.addfile(info, io.BytesIO(binary_bytes));
    }
    return buf.getvalue();
}


def pack_overlay(binary_bytes: bytes, source_root: Path) -> bytes {
    # binary + the jaclang source tree (including any host-built `_precompiled`
    # jir) so the pod reroutes `import jaclang` to it:
    #   {TOOLCHAIN}/bin/jac  and  {TOOLCHAIN}/{OVERLAY_SUBDIR}/jaclang/...
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        info = tarfile.TarInfo(name=f"{TOOLCHAIN_SUBDIR}/{BINARY_ARCNAME}");
        info.size = len(binary_bytes);
        info.mode = 0o755;
        tar.addfile(info, io.BytesIO(binary_bytes));
        jac_pkg = source_root / "jaclang";
        for path in sorted(jac_pkg.rglob("*")) {
            if not path.is_file() or _skip(path) {
                continue;
            }
            rel = path.relative_to(source_root);
            tar.add(str(path), arcname=f"{TOOLCHAIN_SUBDIR}/{OVERLAY_SUBDIR}/{rel}");
        }
    }
    return buf.getvalue();
}


def overlay_pod_path -> str {
    # Where the shipped jaclang source lands in the pod (the dir CONTAINING
    # `jaclang/`), i.e. the value the pod's `[dev] jaclang_source` must point at.
    return f"{TOOLCHAIN_SUBDIR}/{OVERLAY_SUBDIR}";
}


def toolchain_object_key(app_name: str, digest: str) -> str {
    return f"toolchain/{app_name}/{digest}.tar.gz";
}
