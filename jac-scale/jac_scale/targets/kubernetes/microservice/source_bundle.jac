import io;
import base64;
import tarfile;
import from pathlib { Path }

glob _EXCLUDE_DIRS: set[str] = {
         ".jac",
         "__pycache__",
         "node_modules",
         ".git",
         "dist",
         "build",
         ".venv",
         "venv",
         ".mypy_cache",
         ".pytest_cache"
     };
glob _EXCLUDE_FILES: set[str] = {
         ".env",
         "jac.toml",
         "id_rsa",
         "id_dsa",
         "id_ecdsa",
         "id_ed25519"
     };
glob _EXCLUDE_SUFFIXES: tuple = (
         ".pem",
         ".key",
         ".crt",
         ".cer",
         ".p12",
         ".pfx",
         ".jks",
         ".keystore"
     );

glob _CONFIGMAP_MAX_BYTES: int = 900000;

glob SOURCE_ARCHIVE_KEY: str = "source.tar.gz",
     SOURCE_VOLUME_NAME: str = "jac-source",
     SOURCE_MOUNT_PATH: str = "/jac-src",
     APP_VOLUME_NAME: str = "jac-app",
     APP_MOUNT_PATH: str = "/app",
     PYDEPS_DIR: str = "/app/.pydeps",
     JAC_BIN_DIR: str = "/app/.jacbin",
     JAC_ZIG_VERSION: str = "0.16.0";


def source_configmap_name(app_name: str) -> str {
    return f"{app_name}-source";
}


def auto_no_image_fallback(
    build: bool, docker_image_name: str, default_image: str, image_registry: str
) -> bool {
    if build {
        return False;
    }
    user_image = str(docker_image_name or "").strip();
    if user_image and user_image != default_image {
        return False;
    }
    if str(image_registry or "").strip() {
        return False;
    }
    return True;
}


glob IMAGE_STRATEGY_IMAGE: str = "image",
     IMAGE_STRATEGY_NO_IMAGE: str = "no_image";


obj ImageStrategy {
    has mode: str,
        reason: str;
}


def decide_zeroconfig_image_strategy(
    docker_usable: bool, cluster_is_local: bool
) -> ImageStrategy {
    if docker_usable and cluster_is_local {
        return ImageStrategy(
            mode=IMAGE_STRATEGY_IMAGE,
            reason="local cluster + docker available: building a real image and "
            "loading it into the cluster (no registry required)."
        );
    }
    if not docker_usable {
        return ImageStrategy(
            mode=IMAGE_STRATEGY_NO_IMAGE,
            reason="docker is not available: falling back to no-image (source "
            "production image deploy."
        );
    }
    return ImageStrategy(
        mode=IMAGE_STRATEGY_NO_IMAGE,
        reason="remote/unknown cluster with no image registry configured: "
        "kind/k3d/minikube cluster) for a production image deploy."
    );
}


def docker_usable -> bool {
    import shutil;
    import subprocess;
    if shutil.which("docker") is None {
        return False;
    }
    try {
        result = subprocess.run(["docker", "info"], capture_output=True, timeout=8);
        return result.returncode == 0;
    } except Exception {
        return False;
    }
}


def cluster_is_local -> bool {
    try {
        import from jac_scale.microservices.images.cluster_detect {
            detect_cluster_type,
            CLUSTER_MINIKUBE,
            CLUSTER_K3D,
            CLUSTER_KIND
        }
        return detect_cluster_type() in (CLUSTER_MINIKUBE, CLUSTER_K3D, CLUSTER_KIND);
    } except Exception {
        return False;
    }
}


def _is_excluded(rel: any) -> bool {
    for part in rel.parts {
        if part in _EXCLUDE_DIRS {
            return True;
        }
    }
    name = rel.name;
    if name in _EXCLUDE_FILES {
        return True;
    }
    if name == ".env" or name.startswith(".env.") {
        return True;
    }
    if name.endswith(_EXCLUDE_SUFFIXES) {
        return True;
    }
    return False;
}


def _sanitized_jac_toml(base: any) -> (str | None) {
    src = base / "jac.toml";
    if not src.is_file() {
        return None;
    }
    out: list[str] = [];
    skipping = False;
    for line in src.read_text().splitlines() {
        stripped = line.lstrip();
        if stripped.startswith("[") {
            header = stripped.lstrip("[").rstrip().rstrip("]").strip();
            skipping = header == "plugins.scale" or header.startswith("plugins.scale.");
            if skipping {
                continue;
            }
        } elif stripped == "plugins.scale" or stripped.startswith("plugins.scale.") {
            continue;
        }
        if not skipping {
            out.append(line);
        }
    }
    return "\n".join(out) + "\n";
}


def pack_source(project_dir: str) -> bytes {
    base = Path(project_dir).resolve();
    buf = io.BytesIO();
    with tarfile.open(fileobj=buf, mode="w:gz") as tar {
        for path in sorted(base.rglob("*")) {
            if not path.is_file() {
                continue;
            }
            rel = path.relative_to(base);
            if _is_excluded(rel) {
                continue;
            }
            tar.add(str(path), arcname=str(rel));
        }
        sanitized = _sanitized_jac_toml(base);
        if sanitized is not None {
            data = sanitized.encode("utf-8");
            info = tarfile.TarInfo(name="jac.toml");
            info.size = len(data);
            tar.addfile(info, io.BytesIO(data));
        }
    }
    return buf.getvalue();
}


def build_source_configmap(
    app_name: str, namespace: str, project_dir: str
) -> dict[str, any] {
    raw = pack_source(project_dir);
    encoded = base64.b64encode(raw).decode("ascii");
    if len(encoded) > _CONFIGMAP_MAX_BYTES {
        raise ValueError(
            f"Project source is too large for --no-image mode "
            f"({len(encoded)} bytes encoded > {_CONFIGMAP_MAX_BYTES} ConfigMap "
            f"limit). Trim large files from the project, or drop --no-image and "
            f"build a real image (jac start --scale)."
        );
    }
    return {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": source_configmap_name(app_name),
            "namespace": namespace,
            "labels": {"managed": "jac-scale", "jac-scale.role": "source"}
        },
        "binaryData": {SOURCE_ARCHIVE_KEY: encoded}
    };
}


def pinned_install_commands(jac_bin: str) -> list[str] {
    return [
        f"{jac_bin} install 'jac-scale[all]' --global",
        f"{jac_bin} install requests --global"
    ];
}


def _ensure_jac_toml_cmd -> str {
    return (
        f"[ -f {APP_MOUNT_PATH}/jac.toml ] || "
        f"printf '[project]\\nname = \"app\"\\n' > {APP_MOUNT_PATH}/jac.toml"
    );
}


def _https_clone_url(repo_url: str) -> str {
    if repo_url.startswith("git@") and ":" in repo_url {
        (host, path) = repo_url[4:].split(":", 1);
        return f"https://{host}/{path}";
    }
    if repo_url.startswith("ssh://git@") {
        return "https://" + repo_url[len("ssh://git@"):];
    }
    return repo_url;
}


def experimental_bootstrap_script -> str {
    jac_bin: str = f"{JAC_BIN_DIR}/jac";
    steps: list[str] = [
        "set -eu",
        "command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 && command -v zstd >/dev/null 2>&1 || { apt-get update && apt-get install -y --no-install-recommends git curl xz-utils zstd || apk add --no-cache git curl xz zstd; }",
        f"tar xzf {SOURCE_MOUNT_PATH}/{SOURCE_ARCHIVE_KEY} -C {APP_MOUNT_PATH}",
        _ensure_jac_toml_cmd(),
        f"rm -rf {APP_MOUNT_PATH}/jaseci",
        f'git clone --branch "$JACX_BRANCH" --single-branch "$JACX_REPO_URL" {APP_MOUNT_PATH}/jaseci',
        f"cd {APP_MOUNT_PATH}/jaseci",
        '[ -z "$JACX_COMMIT" ] || git checkout "$JACX_COMMIT"',
        "git submodule update --init --recursive",
        'ZARCH="$(uname -m)"; [ "$ZARCH" = "arm64" ] && ZARCH="aarch64"',
        f'ZDIR="zig-${{ZARCH}}-linux-{JAC_ZIG_VERSION}"',
        f'curl -fsSL "https://ziglang.org/download/{JAC_ZIG_VERSION}/${{ZDIR}}.tar.xz" | tar -xJ -C /tmp',
        'export PATH="/tmp/${ZDIR}:$PATH"',
        f"mkdir -p {JAC_BIN_DIR}",
        "( cd jac && zig build )",
        f"cp jac/zig-out/bin/jac {jac_bin}",
        f'export PATH="{JAC_BIN_DIR}:$PATH"',
        f"{jac_bin} install -e ./jac-scale --extras all --global",
        f"[ ! -d ./jac-byllm ] || {jac_bin} install -e ./jac-byllm --global",
        f"[ ! -d ./jac-mcp ] || {jac_bin} install -e ./jac-mcp --global"
    ];
    return " && ".join(steps);
}


def build_bootstrap_init_container(
    base_image: str,
    experimental: bool = False,
    repo_url: str = "",
    branch: str = "main",
    commit: str = ""
) -> dict[str, any] {
    container: dict[str, any] = {
        "name": "jac-bootstrap",
        "image": base_image,
        "command": ["sh", "-c"],
        "volumeMounts": [
            {"name": APP_VOLUME_NAME, "mountPath": APP_MOUNT_PATH},
            {"name": SOURCE_VOLUME_NAME, "mountPath": SOURCE_MOUNT_PATH}
        ]
    };
    if experimental {
        container["args"] = [experimental_bootstrap_script()];
        container["env"] = [
            {"name": "JACX_REPO_URL", "value": _https_clone_url(repo_url)},
            {"name": "JACX_BRANCH", "value": branch},
            {"name": "JACX_COMMIT", "value": commit}
        ];
    } else {
        jac_bin: str = f"{PYDEPS_DIR}/bin/jac";
        steps: list[str] = [
            "set -eu",
            "command -v curl >/dev/null 2>&1 || { apt-get update && apt-get install -y --no-install-recommends curl || apk add --no-cache curl; }",
            f"tar xzf {SOURCE_MOUNT_PATH}/{SOURCE_ARCHIVE_KEY} -C {APP_MOUNT_PATH}",
            _ensure_jac_toml_cmd(),
            f"mkdir -p {PYDEPS_DIR}/bin",
            "curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash",
            f'cp "$HOME/.local/bin/jac" {jac_bin}'
        ];
        steps.extend(pinned_install_commands(jac_bin));
        container["args"] = [" && ".join(steps)];
    }
    return container;
}
