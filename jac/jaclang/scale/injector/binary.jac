import io;
import os;
import shutil;
import subprocess;
import json;
import hashlib;
import logging;
import platform;
import tarfile;
import from pathlib { Path }
import from urllib.request { urlopen }
import from urllib.error { HTTPError }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }

glob logger = logging.getLogger(__name__);

glob BINARY_ARCNAME: str = "bin/jac",
     _HTTP_TIMEOUT: int = 60;


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

    if channel == "local" {
        import from jaclang.scale.config.dev_config { BINARY_PATH_ENV }
        local = os.environ.get(BINARY_PATH_ENV, "");
        if not local {
            raise RuntimeError(
                f"channel 'local' requires {BINARY_PATH_ENV} to point at a jac "
                "binary; it is unset or empty."
            );
        }
        path = Path(local);
        if not path.is_file() {
            raise RuntimeError(
                f"{BINARY_PATH_ENV}={local!r} is not a file; cannot ship a local "
                "jac binary that does not exist."
            );
        }
        logger.info(f"Shipping the local jac binary at {local} ({BINARY_PATH_ENV}).");
        return path.read_bytes();
    }

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

    # Fetch the (tiny) checksum first: it both verifies the download and keys a
    # local cache, so an unchanged release never re-downloads the 130-170MB
    # binary on every deploy (#7179 warm-redeploy cost).
    want = "";
    if checksum_url {
        parts = _http_get_bytes(checksum_url).decode("utf-8").split();
        if not parts {
            raise RuntimeError(
                f"Checksum file at {checksum_url} is empty or malformed; "
                f"cannot verify the downloaded binary."
            );
        }
        want = parts[0].strip().lower();
        cached = _binary_cache_path(channel, arch);
        if cached.is_file() {
            # Read defensively: the file can vanish between is_file() and here
            # (cache-cleanup job, manual removal, a concurrent deploy's rename),
            # so a read failure is just a cache miss, not a failed deploy.
            cached_bytes: bytes | None = None;
            try {
                cached_bytes = cached.read_bytes();
            } except OSError {
                ;
            }
            if cached_bytes is not None
            and hashlib.sha256(cached_bytes).hexdigest() == want {
                logger.info(f"Using the cached {channel} jac binary (checksum match).");
                return cached_bytes;
            }
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
    if want {
        got = hashlib.sha256(payload).hexdigest();
        if got != want {
            raise RuntimeError(
                f"Checksum mismatch for the downloaded jac binary "
                f"(expected {want}, got {got}); refusing to ship it."
            );
        }
        try {
            cached = _binary_cache_path(channel, arch);
            cached.parent.mkdir(parents=True, exist_ok=True);
            tmp = cached.with_suffix(f".{os.getpid()}.tmp");
            tmp.write_bytes(payload);
            tmp.rename(cached);
        } except Exception as e {
            logger.warning(f"Could not cache the downloaded binary ({e}).");
        }
    }
    return payload;
}


def _binary_cache_path(channel: str, arch: str) -> Path {
    # Cache on the DEPLOY-DRIVER machine (laptop / CI runner / operator pod),
    # not the cluster: the driver needs the binary before the PVC exists, and
    # this one copy serves every app/cluster it deploys. The PVC hop is
    # deduplicated separately by the content-addressed seeder (#7198).
    base = os.environ.get("JAC_SCALE_CACHE_DIR", "");
    cache_root = Path(base)
        if base
        else (
            Path(os.environ.get("XDG_CACHE_HOME", "") or (Path.home() / ".cache")) / "jac" / "scale-binaries"
        );
    return Path(cache_root) / f"jac-{channel}-linux-{arch}";
}


def pack_binary_bytes(binary_bytes: bytes) -> bytes {
    import from jaclang.scale.injector.bundle { open_det_tar }
    buf = io.BytesIO();
    (tar, gz) = open_det_tar(buf);
    try {
        with tar {
            info = tarfile.TarInfo(name=f"{TOOLCHAIN_SUBDIR}/{BINARY_ARCNAME}");
            info.size = len(binary_bytes);
            info.mode = 0o755;
            tar.addfile(info, io.BytesIO(binary_bytes));
        }
    } finally {
        gz.close();
    }
    return buf.getvalue();
}


def stage_admin_dist(project_dir: str) -> bool {
    # Put the prebuilt admin console at <app>/.jac/admin so the STABLE-channel
    # gateway skips its ~148s on-pod source build (#7291). Source: the driver's
    # own jaclang package _dist; if absent, one cached host build via jac build.
    import jaclang;
    import from jaclang.scale.runtime.context.util { jac_executable }
    try {
        admin_pkg = Path(str(jaclang.__file__)).parent / "scale" / "admin";
        dist = admin_pkg / "_dist";
        if not (dist / "index.html").is_file() {
            ui = admin_pkg / "ui";
            if not (ui / "main.jac").is_file() {
                return False;
            }
            logger.info("Building the admin console on the host (one-time, cached).");
            result = subprocess.run(
                [jac_executable(), "build", "main.jac"],
                cwd=str(ui),
                capture_output=True,
                text=True,
                timeout=300
            );
            built = ui / ".jac" / "client" / "dist";
            if result.returncode != 0 or not (built / "index.html").is_file() {
                logger.warning(
                    f"Host admin build failed ({result.stderr.strip()[-200:]}); "
                    f"the gateway builds it on boot."
                );
                return False;
            }
            dist.mkdir(parents=True, exist_ok=True);
            for item in built.iterdir() {
                target = dist / item.name;
                if item.is_dir() {
                    if target.exists() {
                        shutil.rmtree(str(target));
                    }
                    shutil.copytree(str(item), str(target));
                } else {
                    shutil.copy2(str(item), str(target));
                }
            }
        }
        dest = Path(project_dir) / ".jac" / "admin";
        dest.mkdir(parents=True, exist_ok=True);
        for item in dist.iterdir() {
            target = dest / item.name;
            if item.is_dir() {
                if target.exists() {
                    shutil.rmtree(str(target));
                }
                shutil.copytree(str(item), str(target));
            } else {
                shutil.copy2(str(item), str(target));
            }
        }
        logger.info("Staged the prebuilt admin console into the app bundle.");
        return True;
    } except Exception as e {
        logger.warning(
            f"Could not stage the admin console ({e}); the gateway builds it on boot."
        );
        return False;
    }
}


def toolchain_object_key(app_name: str, digest: str) -> str {
    return f"toolchain/{app_name}/{digest}.tar.gz";
}
