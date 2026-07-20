import io;
import os;
import json;
import hashlib;
import logging;
import shutil;
import tarfile;
import from pathlib { Path }
import from urllib.request { urlopen }
import from urllib.error { HTTPError }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }
import from jaclang.runtimelib.utils { release_arch, host_arch }

glob logger = logging.getLogger(__name__);

glob BINARY_ARCNAME: str = "bin/jac",
     _HTTP_TIMEOUT: int = 60;


def _node_architecture(k8s_node: object) -> str {
    status = k8s_node?.status;
    info = status?.node_info;
    return str(getattr(info, "architecture", "") or "");
}


def cluster_node_archs -> list[str] {
    try {
        import from kubernetes { client }
    } except ImportError {
        return [];
    }
    nodes: list = [];
    try {
        nodes = list(client.CoreV1Api().list_node(_request_timeout=10).items);
    } except Exception as e {
        logger.warning(f"Could not read the cluster's node architectures ({e}).");
        return [];
    }
    archs: set[str] = set();
    for node in nodes {
        arch = release_arch(_node_architecture(node));
        if arch {
            archs.add(arch);
        }
    }
    return sorted(archs);
}


def node_arch -> str {
    override = os.environ.get("JAC_NODE_ARCH", "");
    if override {
        return release_arch(override);
    }
    archs = cluster_node_archs();
    if len(archs) == 1 {
        return archs[0];
    }
    if archs {
        logger.warning(
            f"Cluster nodes report multiple architectures ({', '.join(archs)}); "
            f"defaulting to the host arch. Set JAC_NODE_ARCH to pick one."
        );
    }
    return host_arch();
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

    if channel == "experimental" {
        channel = "dev";
    }

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
        base = f"https://github.com/{repo}/releases/download/dev";
        binary_url = f"{base}/jac-dev{suffix}";
        checksum_url = f"{binary_url}.sha256";
    } else {
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
        return _fetch_verified_asset(
            binary_url,
            checksum_url,
            _binary_cache_path(channel, arch),
            f"{channel} jac binary"
        );
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
}


def _fetch_verified_asset(
    url: str, checksum_url: str, cache_file: Path, what: str
) -> bytes {
    want = "";
    if checksum_url {
        parts = _http_get_bytes(checksum_url).decode("utf-8").split();
        if not parts {
            raise RuntimeError(
                f"Checksum file at {checksum_url} is empty or malformed; "
                f"cannot verify the download."
            );
        }
        want = parts[0].strip().lower();
        if cache_file.is_file() {
            cached_bytes: bytes | None = None;
            try {
                cached_bytes = cache_file.read_bytes();
            } except OSError {
                ;
            }
            if cached_bytes is not None
            and hashlib.sha256(cached_bytes).hexdigest() == want {
                logger.info(f"Using the cached {what} (checksum match).");
                return cached_bytes;
            }
        }
    }
    payload = _http_get_bytes(url);
    if want {
        got = hashlib.sha256(payload).hexdigest();
        if got != want {
            raise RuntimeError(
                f"Checksum mismatch for the downloaded {what} "
                f"(expected {want}, got {got}); refusing to ship it."
            );
        }
        try {
            cache_file.parent.mkdir(parents=True, exist_ok=True);
            tmp = cache_file.with_suffix(f".{os.getpid()}.tmp");
            tmp.write_bytes(payload);
            tmp.rename(cache_file);
        } except Exception as e {
            logger.warning(f"Could not cache the downloaded {what} ({e}).");
        }
    }
    return payload;
}


glob OFFICIAL_IMAGE: str = "jaseci/jaclang";


def resolve_pod_base_image(
    project_dir: str, configured: str, probe: bool = True
) -> str {
    if configured {
        return configured;
    }
    fallback = "python:3.12-slim";
    import from jaclang.scale.config.dev_config {
        resolve_dev_channel,
        resolve_experimental_pr,
        Channel
    }
    channel = resolve_dev_channel(project_dir);
    if channel == Channel.LOCAL {
        return fallback;
    }
    if channel == Channel.EXPERIMENTAL {
        pr = resolve_experimental_pr(project_dir);
        if not pr {
            logger.warning(
                "[experimental] has no `pr = <N>`; using the dev base image instead."
            );
            tag = "dev";
        } else {
            tag = f"experimental-{pr}";
        }
    } elif channel == Channel.DEV {
        tag = "dev";
    } else {
        tag = "latest";
    }
    image = f"{OFFICIAL_IMAGE}:{tag}";

    if not probe {
        return image;
    }

    try {
        raw = _http_get_bytes(
            f"https://hub.docker.com/v2/repositories/{OFFICIAL_IMAGE}/tags/{tag}"
        );
    } except Exception {
        logger.info(
            f"Official base image {image} is not published or not reachable; "
            f"pods use {fallback}."
        );
        return fallback;
    }

    if channel == Channel.EXPERIMENTAL {
        return image;
    }
    try {
        digest = str(json.loads(raw.decode("utf-8")).get("digest", "") or "");
    } except Exception {
        digest = "";
    }
    if digest.startswith("sha256:") {
        logger.info(f"Pod base image {image} pinned to {digest} for this deploy.");
        return f"{OFFICIAL_IMAGE}@{digest}";
    }
    return image;
}


def _scale_cache_root -> Path {
    base = os.environ.get("JAC_SCALE_CACHE_DIR", "");
    if base {
        return Path(base);
    }
    return Path(os.environ.get("XDG_CACHE_HOME", "") or (Path.home() / ".cache")) / "jac" / "scale-binaries";
}


def _binary_cache_path(channel: str, arch: str) -> Path {
    return _scale_cache_root() / f"jac-{channel}-linux-{arch}";
}


def _admin_dist_cache_path(channel: str) -> Path {
    return _scale_cache_root() / f"jac-{channel}-admin-dist.tar.gz";
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


def _admin_dist_urls(channel: str) -> tuple[str, str] {
    repo = "jaseci-labs/jaseci";
    suffix = "-admin-dist.tar.gz";
    if channel == "dev" {
        url = f"https://github.com/{repo}/releases/download/dev/jac-dev{suffix}";
        return (url, url + ".sha256");
    }
    if channel == "local" {
        return ("", "");
    }
    api = f"https://api.github.com/repos/{repo}/releases/latest";
    meta = json.loads(_http_get_bytes(api).decode("utf-8"));
    dist_url = "";
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
            dist_url = url;
        }
    }
    return (dist_url, checksum_url);
}


def download_admin_dist(channel: str) -> bytes | None {
    try {
        (dist_url, checksum_url) = _admin_dist_urls(channel);
        if not dist_url {
            return None;
        }

        if not checksum_url {
            logger.warning(
                f"No checksum published for the {channel} admin console; "
                "skipping the download so nothing unverified is staged."
            );
            return None;
        }
        return _fetch_verified_asset(
            dist_url,
            checksum_url,
            _admin_dist_cache_path(channel),
            f"{channel} admin console"
        );
    } except Exception as e {
        logger.warning(f"Could not download the admin console asset ({e}).");
        return None;
    }
}


def stage_admin_dist(project_dir: str, channel: str) -> bool {
    dest = Path(project_dir) / ".jac" / "admin";
    try {
        payload = download_admin_dist(channel);
        if payload is None {
            return False;
        }

        tmp = dest.with_name(f".admin.tmp-{os.getpid()}");
        if tmp.exists() {
            shutil.rmtree(str(tmp));
        }
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar {
            tar.extractall(str(tmp), filter="data");
        }
        if not (tmp / "index.html").is_file() {
            shutil.rmtree(str(tmp));
            logger.warning("Admin console asset has no index.html; not staging it.");
            return False;
        }
        dest.parent.mkdir(parents=True, exist_ok=True);
        if dest.exists() {
            shutil.rmtree(str(dest));
        }
        tmp.rename(dest);
        logger.info("Staged the downloaded admin console into the app bundle.");
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
