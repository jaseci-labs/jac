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
# .env / key / cert files are excluded outright; jac.toml is excluded because
# it can hold registry + DB credentials and the pod doesn't need it in
# no-image mode (routes arrive via JAC_SV_ROUTES env, DB creds via injected
# Secret env). Put real secrets in [plugins.scale.secrets] (-> K8s Secret) or
# build an image instead.
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
     PYDEPS_DIR: str = "/app/.pydeps";


"""ConfigMap name holding a service app's packed source (caller pre-sanitizes
app_name to a DNS-1123 value)."""
def source_configmap_name(app_name: str) -> str {
    return f"{app_name}-source";
}


"""Whether `jac start --scale` should auto-fall-back to no-image deploy.

Pure so it is unit-testable. True when the user has NOT configured a way to get
a real image - no explicit `docker_image_name` (i.e. it's still the
`<app>:latest` default), no `image_registry`, and no `--build` - so a
zero-config app deploys by copying local source instead of failing for lack of
an image. An explicit image/registry or `--build` returns False (use the image
pipeline); `--no-image` is handled separately as a forced override.
"""
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


"""Resolve the jaclang/jac-scale versions installed locally so the in-pod
install pins the same releases the developer ran. Returns pip-style specs
(e.g. 'jaclang==0.16.4'); unpinned package name when the version can't be
read."""
def pinned_install_specs -> list[str] {
    import importlib.metadata as _md;
    specs: list[str] = [];
    for pkg in ["jaclang", "jac-scale"] {
        try {
            specs.append(f"{pkg}=={_md.version(pkg)}");
        } except Exception {
            specs.append(pkg);
        }
    }
    return specs;
}


"""initContainer that extracts the packed source into the shared app volume
and pip-installs jac into a target dir on that same volume. The slow install
runs here (no probes) so the main container starts fast against a ready tree."""
def build_bootstrap_init_container(base_image: str) -> dict[str, any] {
    install = " ".join(pinned_install_specs());
    script = (
        "set -eu; "
        f"tar xzf {SOURCE_MOUNT_PATH}/{SOURCE_ARCHIVE_KEY} -C {APP_MOUNT_PATH}; "
        f"pip install --no-cache-dir --target={PYDEPS_DIR} {install}"
    );
    return {
        "name": "jac-bootstrap",
        "image": base_image,
        "command": ["sh", "-c"],
        "args": [script],
        "volumeMounts": [
            {"name": APP_VOLUME_NAME, "mountPath": APP_MOUNT_PATH},
            {"name": SOURCE_VOLUME_NAME, "mountPath": SOURCE_MOUNT_PATH}
        ]
    };
}
