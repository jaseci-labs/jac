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
import from jaclang.runtime.graph_utils { release_arch, host_arch, host_os }

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
    `override = os.environ.get("JAC_NODE_ARCH", "");
    if `override {
        return release_arch(`override);
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


glob GH_REPO: str = "jaseci-labs/jac";


def _ver_key(v: str) -> tuple[int, int, int] {
    parts = (v.strip().split(".") + ["0", "0", "0"])[:3];
    out: list[int] = [];
    for p in parts {
        digits = "".join(
            [
                c
                for c in p
                if c.isdigit()
            ]
        );
        out.append(int(digits) if digits else 0);
    }
    return (out[0], out[1], out[2]);
}


def _valid_version(s: str) -> bool {
    return all([p.isdigit() for p in s.strip().split(".")]);
}


def _split_op(clause: str) -> tuple[str, str] {
    for op in ["==", "!=", ">=", "<=", "~=", ">", "<"] {
        if clause.startswith(op) {
            return (op, clause[len(op):].strip());
        }
    }
    return ("==", clause.strip());
}


def _satisfies(version: str, spec: str) -> bool {
    v = _ver_key(version);
    for raw in spec.split(",") {
        clause = raw.strip();
        if not clause {
            continue;
        }
        (op, target) = _split_op(clause);
        t = _ver_key(target);
        if op == "==" and v != t {
            return False;
        } elif op == "!=" and v == t {
            return False;
        } elif op == ">=" and v < t {
            return False;
        } elif op == "<=" and v > t {
            return False;
        } elif op == ">" and v <= t {
            return False;
        } elif op == "<" and v >= t {
            return False;
        } elif op == "~=" {
            ncomp = len(
                [
                    x
                    for x in target.split(".")
                    if x != ""
                ]
            );
            cap = (t[0], t[1] + 1, 0) if ncomp >= 3 else (t[0] + 1, 0, 0);
            if v < t or v >= cap {
                return False;
            }
        }
    }
    return True;
}


def _exact_of(spec: str) -> str {
    clauses = [
        c.strip()
        for c in spec.split(",")
        if c.strip()
    ];
    if len(clauses) != 1 {
        return "";
    }
    (op, target) = _split_op(clauses[0]);
    if op == "==" and _valid_version(target) {
        return target;
    }
    return "";
}


def _list_release_versions(repo: str) -> list[str] {
    api = f"https://api.github.com/repos/{repo}/releases?per_page=100";
    try {
        arr = json.loads(_http_get_bytes(api).decode("utf-8"));
    } except Exception as e {
        logger.warning(f"Could not list {repo} releases ({e}).");
        return [];
    }
    out: list[str] = [];
    for rel in arr {
        tag = str(rel.get("tag_name", ""));
        if (
            not tag.startswith("v")
            or rel.get("prerelease", False)
            or rel.get("draft", False)
        ) {
            continue;
        }
        version = tag[1:];
        prefix = f"jac-{version}-";
        for asset in rel.get("assets", []) {
            if str(asset.get("name", "")).startswith(prefix) {
                out.append(version);
                break;
            }
        }
    }
    return out;
}


def _resolve_target_version(repo: str, spec: str) -> str {
    spec = spec.strip();
    if not spec {
        return "";
    }
    exact = _exact_of(spec);
    if exact {
        return exact;
    }
    for raw in spec.split(",") {
        clause = raw.strip();
        if clause and not _valid_version(_split_op(clause)[1]) {
            return "";
        }
    }
    matches = [
        v
        for v in _list_release_versions(repo)
        if _satisfies(v, spec)
    ];
    if not matches {
        return "";
    }
    return max(matches, key=_ver_key);
}


def _pick_stable_assets(meta: any, suffix: str) -> tuple[str, str] {
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
    return (binary_url, checksum_url);
}


glob _deploy_version_memo: dict = {};


def resolve_deploy_version(project_dir: str, channel: str) -> str {
    import from jaclang.scale.config.dev_config { Channel }
    if channel != Channel.STABLE.value {
        return "";
    }
    return resolve_pinned_version(project_dir);
}


def deploy_generation_refusal(
    project_dir: str, channel: str = "", offline: bool = False
) -> str {
    import from jaclang.cli.manifest_route { resolve_cli_version }
    import from jaclang.project.config { JacConfig, find_project_root }
    import from jaclang.scale.config.dev_config { Channel, resolve_dev_channel }
    channel = channel or resolve_dev_channel(project_dir).value;
    if offline {
        found = find_project_root(Path(project_dir));
        pinned = (
            _exact_of(str(JacConfig.load(found[1]).project.jac_version or ""))
                if found is not None and channel == Channel.STABLE.value
                else ""
        );
    } else {
        try {
            pinned = resolve_deploy_version(project_dir, channel);
        } except RuntimeError {
            return "";
        }
    }
    running = resolve_cli_version().strip();
    if not pinned or not running {
        return "";
    }
    (pin_major, pin_minor, _) = _ver_key(pinned);
    (run_major, run_minor, _) = _ver_key(running);
    if (pin_major, pin_minor) == (run_major, run_minor) {
        return "";
    }
    return (
        f"this deployer is jac {running} and cannot deploy an app pinned to "
        f"{pinned}. the deploying jac renders the manifests and provisions the "
        "database, so a different minor line stands up a backend the pod "
        f"cannot use. upgrade the deployer, or pin [project] jac-version to "
        f"{run_major}.{run_minor}."
    );
}


def resolve_console_version(
    project_dir: str, channel: str, deploy_version: str
) -> str {
    import from jaclang.scale.config.dev_config { Channel }
    if deploy_version {
        return deploy_version;
    }
    if channel == Channel.LOCAL.value {
        return resolve_pinned_version(project_dir);
    }
    return "";
}


def resolve_pinned_version(project_dir: str) -> str {
    import from jaclang.project.config { JacConfig, find_project_root }
    found = find_project_root(Path(project_dir));
    if found is None {
        return "";
    }
    toml = found[1];
    prefix = f"{toml}||";

    stamp = hashlib.sha256(toml.read_bytes()).hexdigest();
    key = prefix + stamp;
    if key in _deploy_version_memo {
        return _deploy_version_memo[key];
    }
    for k in list(_deploy_version_memo.keys()) {
        if str(k).startswith(prefix) {
            del _deploy_version_memo[k];
        }
    }
    spec = JacConfig.load(toml).project.jac_version;
    if not spec {
        _deploy_version_memo[key] = "";
        return "";
    }
    target = _resolve_target_version(GH_REPO, spec);
    if not target {
        raise RuntimeError(
            f"jac-version {spec!r} matches no published {GH_REPO} release. Fix "
            f"[project] jac-version, or remove it to deploy on the latest release."
        );
    }
    _deploy_version_memo[key] = target;
    return target;
}


def reset_deploy_version_cache {
    _deploy_version_memo.clear();
}


def host_seal_platform -> str {
    plat = host_os();
    if plat in ("linux", "macos") {
        return plat;
    }
    raise RuntimeError(
        f"Deploying from a {plat} host is not supported: sealing the app "
        f"runs a host-runnable jac release binary, and {GH_REPO} publishes "
        "linux and macos binaries only. Deploy from Linux or macOS (WSL2 "
        "works on Windows)."
    );
}


def stable_release_meta(version: str = "") -> dict {
    api = f"https://api.github.com/repos/{GH_REPO}/releases/tags/v{version}"
        if version
        else f"https://api.github.com/repos/{GH_REPO}/releases/latest";
    try {
        return dict(json.loads(_http_get_bytes(api).decode("utf-8")));
    } except HTTPError as e {
        if e.code == 404 and version {
            raise RuntimeError(
                f"Pinned jac-version v{version} is not a published {GH_REPO} "
                "release; fix [project] jac-version or remove it for latest."
            );
        }
        raise;
    }
}


def _no_asset_message(meta: dict, suffix: str, version: str) -> str {
    tag = str(meta.get("tag_name", version or "latest"));
    return (
        f"No `jac-*{suffix}` asset on the {GH_REPO} release ({tag}). The node "
        "arch may be unpublished; set JAC_NODE_ARCH or check "
        f"https://github.com/{GH_REPO}/releases."
    );
}


def preflight_pod_runtime(project_dir: str, channel: str, arch: str) -> str {
    import from jaclang.scale.config.dev_config { Channel }
    if channel != Channel.STABLE.value {
        return "";
    }
    version = resolve_deploy_version(project_dir, channel);
    meta = stable_release_meta(version);

    needed = {f"-linux-{arch}", f"-{host_seal_platform()}-{host_arch()}"};
    for suffix in sorted(needed) {
        if not _pick_stable_assets(meta, suffix)[0] {
            raise RuntimeError(_no_asset_message(meta, suffix, version));
        }
    }
    return version;
}


def download_release_binary(
    channel: str, arch: str, version: str = "", plat: str = "linux"
) -> bytes {
    repo = GH_REPO;
    suffix = f"-{plat}-{arch}";
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
        meta = stable_release_meta(version);
        (binary_url, checksum_url) = _pick_stable_assets(meta, suffix);
        if not binary_url {
            raise RuntimeError(_no_asset_message(meta, suffix, version));
        }
        if version {
            logger.info(f"Shipping the pinned pod runtime jac {version}.");
        }
    }

    try {
        return _fetch_verified_asset(
            binary_url,
            checksum_url,
            _binary_cache_path(channel, arch, plat, version),
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


def _write_cache_atomic(cache_file: Path, payload: bytes) {
    cache_file.parent.mkdir(parents=True, exist_ok=True);
    tmp = cache_file.with_name(f"{cache_file.name}.{os.getpid()}.tmp");
    tmp.write_bytes(payload);
    tmp.replace(cache_file);
}


def _fetch_verified_asset(
    url: str, checksum_url: str, cache_file: Path, what: str
) -> bytes {
    import from jaclang.toolchains.store { Artifact, fetch }
    if not checksum_url {
        raise RuntimeError(
            f"No checksum is available for {what}; refusing an unverified download."
        );
    }
    parts = _http_get_bytes(checksum_url).decode("utf-8").split();
    if not parts {
        raise RuntimeError(f"Checksum file at {checksum_url} is empty or malformed.");
    }
    digest = parts[0].strip().lower();
    artifact = Artifact("jac-deployment", digest, "asset", url, digest);
    return fetch(artifact, cache_file).read_bytes();
}


def host_toolchain_path(project_dir: str, channel: str = "") -> str {
    import from jaclang.cli.manifest_route { resolve_cli_version }
    import from jaclang.scale.config.dev_config { resolve_dev_channel }

    channel = channel or resolve_dev_channel(project_dir).value;
    version = resolve_deploy_version(project_dir, channel);
    if not version or version == resolve_cli_version().strip() {
        return "";
    }
    plat = host_seal_platform();
    arch = host_arch();
    payload = download_release_binary(channel, arch, version, plat);
    path = _binary_cache_path(channel, arch, plat, version);
    if not path.is_file() {
        _write_cache_atomic(path, payload);
    }
    path.chmod(0o755);
    logger.info(f"Host build steps for this deploy run the pinned jac {version}.");
    return str(path);
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
        resolve_pinned_spec,
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
        target = resolve_deploy_version(project_dir, channel.value)
            if probe
            else _exact_of(resolve_pinned_spec(project_dir));
        tag = target or "latest";
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
    return Path(os.environ.get("XDG_CACHE_HOME", "") or (Path.home() / ".cache"))
        / "jac"
        / "scale-binaries";
}


def _binary_cache_path(
    channel: str, arch: str, plat: str = "linux", version: str = ""
) -> Path {
    tag = f"{channel}-{version}" if version else channel;
    return _scale_cache_root() / f"jac-{tag}-{plat}-{arch}";
}


def _admin_dist_cache_path(channel: str, version: str = "") -> Path {
    tag = f"{channel}-{version}" if version else channel;
    return _scale_cache_root() / f"jac-{tag}-admin-dist.tar.gz";
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


def admin_dist_source(channel: str, version: str) -> str {
    if channel == "dev" {
        return "dev";
    }
    if channel == "local" and not version {
        return "";
    }
    return "release";
}


def _admin_dist_urls(channel: str, version: str = "") -> tuple[str, str] {
    repo = GH_REPO;
    suffix = "-admin-dist.tar.gz";
    source = admin_dist_source(channel, version);
    if source == "dev" {
        url = f"https://github.com/{repo}/releases/download/dev/jac-dev{suffix}";
        return (url, url + ".sha256");
    }
    if not source {
        return ("", "");
    }

    api = f"https://api.github.com/repos/{repo}/releases/tags/v{version}"
        if version
        else f"https://api.github.com/repos/{repo}/releases/latest";
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
    if version and dist_url and not checksum_url {
        raise RuntimeError(
            f"Pinned jac {version} publishes an admin console without a "
            f"checksum; refusing to stage it unverified."
        );
    }
    return (dist_url, checksum_url);
}


def download_admin_dist(channel: str, version: str = "") -> bytes | None {
    try {
        (dist_url, checksum_url) = _admin_dist_urls(channel, version);
        if not dist_url {
            if version {
                logger.warning(
                    f"Pinned jac {version} publishes no admin console asset; "
                    f"the gateway builds it on boot."
                );
            }
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
            _admin_dist_cache_path(channel, version),
            f"{channel} admin console"
        );
    } except Exception as e {
        if version {
            raise;
        }
        logger.warning(f"Could not download the admin console asset ({e}).");
        return None;
    }
}


def stage_admin_dist(project_dir: str, channel: str, version: str = "") -> bool {
    dest = Path(project_dir) / ".jac" / "admin";
    try {
        payload = download_admin_dist(channel, version);
        if payload is None {
            if version and dest.exists() {
                shutil.rmtree(str(dest));
                logger.info(
                    f"Removed the previously staged admin console; pinned jac "
                    f"{version} publishes none."
                );
            }
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
            if version {
                raise RuntimeError(
                    f"Pinned jac {version} admin console asset has no index.html."
                );
            }
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
        if version {
            raise;
        }
        logger.warning(
            f"Could not stage the admin console ({e}); the gateway builds it on boot."
        );
        return False;
    }
}


def toolchain_object_key(app_name: str, digest: str) -> str {
    return f"toolchain/{app_name}/{digest}.tar.gz";
}
