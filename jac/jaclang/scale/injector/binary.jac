import io;
import os;
import json;
import shutil;
import hashlib;
import logging;
import platform;
import subprocess;
import tarfile;
import tempfile;
import from pathlib { Path }
import from urllib.request { urlopen }
import from urllib.error { HTTPError }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }

glob logger = logging.getLogger(__name__);

glob BINARY_ARCNAME: str = "bin/jac",
     OVERLAY_SUBDIR: str = "jaclang-src",
     JIR_SEED_SUBDIR: str = "jir-seed",
     _HTTP_TIMEOUT: int = 60,
     _SUBPROCESS_TIMEOUT: int = 300,
     _JASECI_REPO: str = "https://github.com/jaseci-labs/jaseci",
     _SKIP_DIRS: set[str] = {"__pycache__", ".git", "node_modules", ".jac"};


def host_arch -> str {
    m = platform.machine();
    return "aarch64" if m in ("arm64", "aarch64") else m;
}


def node_arch -> str {
    return os.environ.get("JAC_NODE_ARCH", "") or host_arch();
}


def _http_get_bytes(url: str) -> bytes {
    resp = urlopen(url, timeout=_HTTP_TIMEOUT);
    try {
        return bytes(resp.read());
    } finally {
        resp.close();
    }
}


def download_release_binary(channel: str, arch: str) -> bytes {
    repo = "jaseci-labs/jaseci";
    suffix = f"-linux-{arch}";
    binary_url = "";
    checksum_url = "";

    if channel == "dev" {
        # The rolling `dev` prerelease has fixed asset names, so build the URL directly and skip the API (anonymous, 60 req/hr, exhausted on CI).
        base = f"https://github.com/{repo}/releases/download/dev";
        binary_url = f"{base}/jac-dev{suffix}";
        checksum_url = f"{binary_url}.sha256";
    } else {
        # Stable asset names carry the release version, so resolve them through the API.
        api = f"https://api.github.com/repos/{repo}/releases/latest";
        meta = json.loads(_http_get_bytes(api).decode("utf-8"));
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
            tag = meta.get("tag_name", "latest");
            raise RuntimeError(
                f"No `jac-*{suffix}` asset on the {channel} release ({tag}). The "
                f"node arch may be unpublished; set JAC_NODE_ARCH or check "
                f"https://github.com/{repo}/releases."
            );
        }
    }

    try {
        payload = _http_get_bytes(binary_url);
    } except HTTPError as e {
        if e.code == 404 {
            raise RuntimeError(
                f"No `jac-*{suffix}` binary published for this arch on the "
                f"{channel} release; set JAC_NODE_ARCH or check "
                f"https://github.com/{repo}/releases."
            );
        }
        raise;
    }
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
    if repo {
        return _clone_jac_source(repo, branch or "main");
    }
    if jaclang_source {
        local = (Path(project_dir) / jaclang_source).resolve();
        if (local / "jaclang").is_dir() {
            return (local, None);
        }
        logger.warning(
            f"[dev] jaclang_source '{jaclang_source}' has no 'jaclang/' package "
            f"under {local}; overlaying a fresh {_JASECI_REPO}@main clone instead."
        );
    }
    return _clone_jac_source(_JASECI_REPO, "main");
}


def cleanup_overlay_source(cleanup_root: (Path | None)) {
    if cleanup_root is not None {
        shutil.rmtree(cleanup_root, ignore_errors=True);
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
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        info = tarfile.TarInfo(name=f"{TOOLCHAIN_SUBDIR}/{BINARY_ARCNAME}");
        info.size = len(binary_bytes);
        info.mode = 0o755;
        tar.addfile(info, io.BytesIO(binary_bytes));
    }
    return buf.getvalue();
}


def ensure_admin_dist_built(source_root: Path) -> None {
    # Build the admin console `_dist` on the host (like the client bundle) so the gateway ships it pre-built instead of doing a heavy on-pod `bun` build that can OOM-kill the container.
    admin = source_root / "jaclang" / "scale" / "admin";
    dist = admin / "_dist";
    if (dist / "index.html").is_file() {
        return;
    }
    ui = admin / "ui";
    if not (ui / "main.jac").is_file() {
        logger.warning(
            f"Admin UI source not found at {ui}; the gateway will build the "
            f"admin console on-pod instead."
        );
        return;
    }
    logger.info(
        "Building the admin console on the host (ships pre-built to the gateway)."
    );
    try {
        result = subprocess.run(
            ["jac", "build", "main.jac"],
            cwd=str(ui),
            capture_output=True,
            text=True,
            timeout=_SUBPROCESS_TIMEOUT
        );
        if result.returncode != 0 {
            logger.warning(
                f"Host admin build failed ({result.stderr.strip()}); the gateway "
                f"will build it on-pod instead."
            );
            return;
        }
    } except Exception as e {
        logger.warning(
            f"Host admin build error ({e}); the gateway will build it on-pod."
        );
        return;
    }
    built = ui / ".jac" / "client" / "dist";
    if not (built / "index.html").is_file() {
        logger.warning(f"Host admin build produced no dist at {built}.");
        return;
    }
    dist.mkdir(parents=True, exist_ok=True);
    for item in built.iterdir() {
        target = dist / item.name;
        if item.is_dir() {
            if target.exists() {
                shutil.rmtree(target);
            }
            shutil.copytree(item, target);
        } else {
            shutil.copy2(item, target);
        }
    }
    logger.info("Admin console built; shipping it in the overlay.");
}


glob _JIR_ADOPT_PY: str = """\
# Re-home host-precompiled .jir seeds to this pod's cache paths (#7138).
# The module key inside each seed is content-derived so it stays valid; only
# the cache FILENAME hashes the absolute source path, which differs on the pod.
import os
import shutil
from pathlib import Path
from jaclang.jac0core.jir import get_module_cache_path

seed_root = Path(__file__).resolve().parent
src_root = seed_root.parent / "jaclang-src"
adopted = 0
for seed in seed_root.rglob("*.jir"):
    rel = str(seed.relative_to(seed_root))[:-4]  # strip trailing ".jir"
    source = src_root / rel
    if not source.is_file():
        continue
    dest = get_module_cache_path(str(source))
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(str(seed), str(dest))
    os.utime(str(dest), None)  # fresher than the untarred source -> cache valid
    adopted += 1
print("[jac-scale] adopted %d host-precompiled modules" % adopted)
""";


def _host_jir_cache_for(source_path: Path) -> (Path | None) {
    # Host-side compiled .jir for this source, if this deploy driver (same
    # binary the pods run) already compiled it. Best-effort by design.
    try {
        import from jaclang.jac0core.jir { get_module_cache_path }
        cache = get_module_cache_path(str(source_path));
        return cache if cache.is_file() else None;
    } except Exception {
        return None;
    }
}


def pack_overlay(binary_bytes: bytes, source_root: Path) -> bytes {
    ensure_admin_dist_built(source_root);
    seeded = 0;
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
            # Ship the host's compiled .jir beside the source (as a jir-seed):
            # the module key is content-derived but the cache FILENAME hashes
            # the absolute source path, so pods re-home each seed to their own
            # cache path at boot and `jac install` validates instead of
            # recompiling the whole overlay in every pod (#7138).
            if str(path).endswith(".jac") {
                cache = _host_jir_cache_for(path);
                if cache is not None {
                    tar.add(
                        str(cache),
                        arcname=f"{TOOLCHAIN_SUBDIR}/{JIR_SEED_SUBDIR}/{rel}.jir"
                    );
                    seeded += 1;
                }
            }
        }
        if seeded {
            adopt = _JIR_ADOPT_PY.encode("utf-8");
            info = tarfile.TarInfo(
                name=f"{TOOLCHAIN_SUBDIR}/{JIR_SEED_SUBDIR}/_adopt.py"
            );
            info.size = len(adopt);
            tar.addfile(info, io.BytesIO(adopt));
        }
    }
    if seeded {
        logger.info(f"Packed {seeded} host-precompiled modules into the overlay.");
    }
    return buf.getvalue();
}


def overlay_pod_path -> str {
    return f"{TOOLCHAIN_SUBDIR}/{OVERLAY_SUBDIR}";
}


def toolchain_object_key(app_name: str, digest: str) -> str {
    return f"toolchain/{app_name}/{digest}.tar.gz";
}
