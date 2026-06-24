"""Package a project's local source for no-image microservice deploys.

The no-image deploy path (jac start --scale --no-image) skips docker build +
push entirely. Instead the project's source tree is tar+gzipped, carried into
the cluster as a ConfigMap, extracted into an emptyDir by an initContainer, and
run on a generic Python base image with jac installed at pod startup. This is a
dev / preview convenience; production should build and push a real image.

ConfigMaps are capped at etcd's ~1 MiB object size, so this is only viable for
small source trees (the .jac files + shared modules). Build artifacts
(node_modules, dist, .jac cache, __pycache__) are excluded from the archive.
"""

import io;
import base64;
import tarfile;
import from pathlib { Path }

# Directories never shipped into the cluster: build output, caches, vendored
# deps, VCS metadata. Matches setup.jac's scan exclusions plus virtualenvs.
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
# Secret-bearing files are NEVER packed into the ConfigMap (it's stored
# unencrypted in etcd and readable by anyone with `kubectl get configmap`).
# .env / key / cert files are excluded outright. The raw jac.toml is excluded
# too (it can hold registry + DB creds under `[plugins.scale]`), but a
# `[plugins.scale]`-stripped copy is added back by `pack_source` (see
# `_sanitized_jac_toml`) so pods still get the app + client-build config they
# need. Keep app-level secrets out of jac.toml; use [plugins.scale.secrets]
# (-> K8s Secret) or env.
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

# etcd caps a single object at ~1 MiB; the base64-encoded archive must fit
# under that with headroom for the rest of the ConfigMap manifest.
glob _CONFIGMAP_MAX_BYTES: int = 900000;

# Pod-side contract shared with manifest_builder._build_pod_spec.
glob SOURCE_ARCHIVE_KEY: str = "source.tar.gz",
     SOURCE_VOLUME_NAME: str = "jac-source",
     SOURCE_MOUNT_PATH: str = "/jac-src",
     APP_VOLUME_NAME: str = "jac-app",
     APP_MOUNT_PATH: str = "/app",
     PYDEPS_DIR: str = "/app/.pydeps",
     # Experimental mode installs an editable jaseci checkout into a venv on
     # the shared app volume (jac plugins can't go into PYDEPS_DIR via
     # `pip --target`); the main container runs out of this venv instead.
     VENV_DIR: str = "/app/.venv";


"""ConfigMap name holding a service app's packed source (caller pre-sanitizes
app_name to a DNS-1123 value)."""
def source_configmap_name(app_name: str) -> str {
    return f"{app_name}-source";
}


"""True if `rel` (a project-relative Path) is a build artifact or secret file
that must not be packed into the ConfigMap."""
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
    # .env, .env.local, .env.production, ... (dotenv family)
    if name == ".env" or name.startswith(".env.") {
        return True;
    }
    if name.endswith(_EXCLUDE_SUFFIXES) {
        return True;
    }
    return False;
}


"""The project's jac.toml with the `[plugins.scale...]` tables (deploy creds)
removed, or None when there's no jac.toml."""
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
            # Dotted-key form of a jac-scale setting; drop it defensively.
            continue;
        }
        if not skipping {
            out.append(line);
        }
    }
    return "\n".join(out) + "\n";
}


"""Tar+gzip the project dir (excluding build artifacts + secret files) into
raw bytes."""
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


"""ConfigMap manifest carrying the base64 source archive in binaryData.

K8s base64-decodes binaryData when mounting, so the in-pod file is the raw
.tar.gz. Raises ValueError when the archive exceeds the ConfigMap size limit
so the user gets an actionable message instead of an opaque apply failure.
"""
def build_source_configmap(
    app_name: str, namespace: str, project_dir: str
) -> dict[str, any] {
    raw = pack_source(project_dir);
    encoded = base64.b64encode(raw).decode("ascii");
    if len(encoded) > _CONFIGMAP_MAX_BYTES {
        raise ValueError(
            f"Project source is too large to ship into the cluster "
            f"({len(encoded)} bytes encoded > {_CONFIGMAP_MAX_BYTES} ConfigMap "
            f"limit). Trim large files from the project before deploying."
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


"""In-pod pip specs, pinned to the versions the developer ran. `requests` is a
runtime dep of the scale plugin but jac-scale ships it only in the `test`
extra, so it (and the `[all]` deploy extras) must be installed explicitly or
the plugin fails to load in every pod. jac-client is added only when present
locally (fullstack apps)."""
def pinned_install_specs -> list[str] {
    import importlib.metadata as _md;
    specs: list[str] = [];
    # (pip spec name, distribution name, required-even-if-absent).
    targets: list[tuple[str, str, bool]] = [
        ("jaclang", "jaclang", True),
        ("jac-scale[all]", "jac-scale", True),
        ("requests", "requests", True),
        ("jac-client", "jac-client", False)
    ];
    for (pip_name, dist_name, required) in targets {
        try {
            specs.append(f"{pip_name}=={_md.version(dist_name)}");
        } except Exception {
            if required {
                specs.append(pip_name);
            }
        }
    }
    return specs;
}


"""Shell command that writes a minimal jac.toml into the extracted source if
one isn't there. The real jac.toml is excluded from the bundle (it can hold
credentials), but `jac start <svc>.jac` requires a project jac.toml to exist,
so the service pods need at least a stub."""
def _ensure_jac_toml_cmd -> str {
    return (
        f"[ -f {APP_MOUNT_PATH}/jac.toml ] || "
        f"printf '[project]\\nname = \"app\"\\n' > {APP_MOUNT_PATH}/jac.toml"
    );
}


"""Normalize an SCP-style or `ssh://` GitHub URL to anonymous HTTPS; init pods
have no SSH key. Other URLs pass through unchanged."""
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


"""Bootstrap script for experimental mode: clone the jaseci repo/branch into a
venv on the shared volume and editable-install it. repo/branch/commit arrive as
`JACX_*` env vars (data, never spliced into shell code), so a value with a space
or `$(...)` can't break or inject the clone."""
def experimental_bootstrap_script -> str {
    steps: list[str] = [
        "set -eu",
        # Install git via whichever package manager the base image ships (Debian
        # slim -> apt, Alpine -> apk); skip entirely when it's already present.
        "command -v git >/dev/null 2>&1 || { apt-get update && apt-get install -y --no-install-recommends git || apk add --no-cache git; }",
        f"tar xzf {SOURCE_MOUNT_PATH}/{SOURCE_ARCHIVE_KEY} -C {APP_MOUNT_PATH}",
        _ensure_jac_toml_cmd(),
        f"python3 -m venv {VENV_DIR}",
        f". {VENV_DIR}/bin/activate",
        f"rm -rf {APP_MOUNT_PATH}/jaseci",
        f'git clone --branch "$JACX_BRANCH" --single-branch "$JACX_REPO_URL" {APP_MOUNT_PATH}/jaseci',
        f"cd {APP_MOUNT_PATH}/jaseci",
        # Optional pin: skip when unset, but surface a real checkout failure.
        '[ -z "$JACX_COMMIT" ] || git checkout "$JACX_COMMIT"',
        "git submodule update --init --recursive",
        "pip install pluggy",
        # --force-reinstall --no-deps so the local checkout wins over any
        # already-resolved release of the same version.
        "pip install --force-reinstall --no-deps -e ./jac",
        "jac install -e ./jac-scale --extras all",
        # Only when the fork ships jac-client: skip-when-absent, but let a genuine
        # install failure propagate (don't blanket-swallow with `|| true`).
        '[ ! -d ./jac-client ] || jac install -e ./jac-client'
    ];
    return " && ".join(steps);
}


"""initContainer that extracts the packed source into the shared app volume and
installs jac onto that same volume (so the main container starts fast against a
ready tree). PyPI-pinned by default; in experimental mode it git-clones the
jaseci repo/branch into a venv on the shared volume instead."""
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
        # Untrusted repo/branch/commit ride as env data, not shell code, so they
        # can't break or inject the clone (see experimental_bootstrap_script).
        container["env"] = [
            {"name": "JACX_REPO_URL", "value": _https_clone_url(repo_url)},
            {"name": "JACX_BRANCH", "value": branch},
            {"name": "JACX_COMMIT", "value": commit}
        ];
    } else {
        # Single-quote each spec so the `[all]` extras marker isn't treated as a
        # shell glob char-class by the `sh -c` bootstrap.
        install = " ".join([f"'{spec}'" for spec in pinned_install_specs()]);
        container["args"] = [
            "set -eu; "
            f"tar xzf {SOURCE_MOUNT_PATH}/{SOURCE_ARCHIVE_KEY} -C {APP_MOUNT_PATH}; "
            f"{_ensure_jac_toml_cmd()}; "
            f"pip install --no-cache-dir --target={PYDEPS_DIR} {install}"
        ];
    }
    return container;
}
