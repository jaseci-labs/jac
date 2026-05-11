"""Auto-build + auto-distribute pipeline for `jac start --scale`.

Detect cluster -> pick Dockerfile -> docker build -> distribute (minikube
internal daemon / k3d-kind image load / registry push) -> return image
tag for the manifest builder.
"""

import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Any }
import from jac_scale.microservices._cluster_detect {
    detect_cluster_type,
    get_minikube_docker_env,
    k3d_cluster_name,
    kind_cluster_name,
    _active_context_name,
    CLUSTER_MINIKUBE,
    CLUSTER_K3D,
    CLUSTER_KIND,
    CLUSTER_REMOTE,
    CLUSTER_UNKNOWN
}


# Subprocess timeouts (seconds). Largest is docker build because first
# minikube builds download apt + pip from scratch.
glob _DOCKER_BUILD_TIMEOUT_S: int = 1800,
     _DOCKER_PUSH_TIMEOUT_S: int = 600,
     _DOCKER_PROBE_TIMEOUT_S: int = 5,
     _DOCKER_INSPECT_TIMEOUT_S: int = 10,
     _CLUSTER_IMAGE_LOAD_TIMEOUT_S: int = 180,
     _JAC_BUILD_TIMEOUT_S: int = 300;

# Embedded fallback Dockerfile, used when neither developer-checkout
# nor shipped Dockerfile.microservice is available.
glob _EMBEDDED_DOCKERFILE: str = "FROM python:3.12-slim\n\n"
     "RUN apt-get update \\\n"
     "    && apt-get install -y --no-install-recommends git curl \\\n"
     "    && rm -rf /var/lib/apt/lists/*\n\n"
     "RUN git config --system --add safe.directory '*'\n\n"
     "RUN pip install --no-cache-dir --upgrade pip\n\n"
     "RUN pip install --no-cache-dir \"jac-scale[deploy,data]>=0.2.15\" "
     "jac-client\n\n"
     "WORKDIR /app\n"
     "COPY . /app\n\n"
     "RUN if [ -f jac.toml ]; then jac install || true; fi\n\n"
     "RUN jac --version\n\n"
     "EXPOSE 8000\n",
     # Embedded .dockerignore. Without one, docker build sends GB of
     # .git + caches to the daemon and times out.
     _EMBEDDED_DOCKERIGNORE: str = "# Auto-generated .dockerignore.\n"
     ".git\n"
     ".gitignore\n"
     ".github\n"
     ".vscode\n"
     ".idea\n"
     ".DS_Store\n"
     "**/__pycache__\n"
     "**/*.pyc\n"
     "**/*.egg-info\n"
     "**/.pytest_cache\n"
     "**/.mypy_cache\n"
     "**/.ruff_cache\n"
     "**/.venv\n"
     "**/venv\n"
     # Anchored - **/dist would also drop .jac/client/dist (FE bundle).
     "/dist\n"
     "/build\n"
     # Keep .jac/client/dist (FE bundle); drop caches + per-pod state.
     "**/.jac/cache\n"
     "**/.jac/data\n"
     "**/.jac/logs\n"
     "**/.jac/run\n"
     "**/.jac/__pycache__\n"
     "**/__jac_gen__\n"
     "**/node_modules\n"
     "**/.vite\n"
     "**/.next\n"
     ".env\n"
     ".env.*\n";


"""Walk up looking for jac/ + jac-scale/ siblings (developer checkout
detection). Returns the repo root or None."""
def find_jaseci_repo_root(start: Path, max_levels: int = 8) -> Path | None {
    current = start.resolve();
    for _ in range(max_levels) {
        if (current / "jac").is_dir() and (current / "jac-scale").is_dir() {
            return current;
        }
        if current.parent == current {
            return None;
        }
        current = current.parent;
    }
    return None;
}


"""Locate the shipped Dockerfile.microservice (PyPI install path).
Returns Path or None. Extracted so tests can mock it."""
def find_shipped_dockerfile -> Path | None {
    try {
        import jac_scale;
        f = jac_scale.__file__;
        if f is None {
            return None;
        }
        pkg_dir = Path(f).parent;
        shipped = pkg_dir.parent / "scripts" / "Dockerfile.microservice";
        if shipped.is_file() {
            return shipped;
        }
    } except Exception as _ {
        ;
    }
    return None;
}


"""Pick (dockerfile, context, build_args) in priority order:
  1. <project>/Dockerfile.microservice (user override)
  2. Developer-checkout -> repo-root Dockerfile.microservice.exp (PR testing)
  3. Shipped <pkg>/scripts/Dockerfile.microservice (PyPI install)
  4. Embedded fallback at <project>/.jac/Dockerfile.gen"""
def resolve_dockerfile(project_dir: Path) -> tuple[Path, Path, dict[str, str]] {
    user_dockerfile = project_dir / "Dockerfile.microservice";
    if user_dockerfile.is_file() {
        return (user_dockerfile, project_dir, {});
    }

    repo_root = find_jaseci_repo_root(project_dir);
    if repo_root {
        exp_df = repo_root / "jac-scale" / "scripts" / "Dockerfile.microservice.exp";
        if exp_df.is_file() {
            try {
                rel_project = str(
                    project_dir.resolve().relative_to(repo_root.resolve())
                );
            } except ValueError {
                rel_project = "";
            }
            return (
                exp_df,
                repo_root,
                {"PROJECT_PATH": rel_project} if rel_project else {}
            );
        }
    }

    shipped = find_shipped_dockerfile();
    if shipped is not None {
        return (shipped, project_dir, {});
    }

    cache_dir = project_dir / ".jac";
    cache_dir.mkdir(parents=True, exist_ok=True);
    generated = cache_dir / "Dockerfile.gen";
    generated.write_text(_EMBEDDED_DOCKERFILE);
    return (generated, project_dir, {});
}


"""Write the embedded .dockerignore if the context doesn't have one.
Never overwrites. Returns True if written."""
def ensure_dockerignore(context_dir: Path) -> bool {
    target = context_dir / ".dockerignore";
    if target.exists() {
        return False;
    }
    try {
        target.write_text(_EMBEDDED_DOCKERIGNORE);
    } except OSError {
        return False;
    }
    return True;
}


"""Run `docker build` with optional env override (e.g. minikube's daemon).
Streams output. Raises RuntimeError on failure."""
def run_docker_build(
    context_dir: Path,
    image_tag: str,
    dockerfile_path: Path,
    build_args: dict[str, str],
    env_overrides: dict[str, str] | None = None
) {
    ensure_dockerignore(context_dir);

    if shutil.which("docker") is None {
        raise RuntimeError(
            "docker CLI not found in PATH. Install Docker Desktop "
            "(https://docs.docker.com/get-docker/) and retry."
        );
    }

    env = dict(os.environ);
    if env_overrides {
        env.update(env_overrides);
    }

    # --progress=plain is BuildKit-only; legacy builder rejects it.
    buildkit_ok: bool = False;
    try {
        probe = subprocess.run(
            ["docker", "buildx", "version"],
            capture_output=True,
            text=True,
            timeout=_DOCKER_PROBE_TIMEOUT_S,
            env=env
        );
        buildkit_ok = probe.returncode == 0;
    } except Exception {
        buildkit_ok = False;
    }

    cmd: list[str] = ["docker", "build"];
    if buildkit_ok {
        cmd.append("--progress=plain");
    }
    cmd.extend(["-t", image_tag, "-f", str(dockerfile_path)]);
    for (key, value) in build_args.items() {
        cmd.append("--build-arg");
        cmd.append(f"{key}={value}");
    }
    cmd.append(str(context_dir));

    # Stream output (no capture) so first-time multi-minute builds show signs of life.
    try {
        result = subprocess.run(cmd, env=env, timeout=_DOCKER_BUILD_TIMEOUT_S);
    } except subprocess.TimeoutExpired {
        raise RuntimeError(
            f"docker build timed out after {_DOCKER_BUILD_TIMEOUT_S}s. "
            f"Context ({context_dir}) likely too large or first-minikube build is slow.\n"
            f"  - Check .dockerignore: ls {context_dir}/.dockerignore\n"
            f"  - Manual: docker build -f {dockerfile_path} --progress=plain {context_dir}"
        );
    }

    if result.returncode != 0 {
        raise RuntimeError(
            f"docker build failed (exit {result.returncode}). See output above.\n"
            f"  cmd: {' '.join(cmd)}"
        );
    }
}


"""Run `k3d image import <tag> -c <cluster>`."""
def run_k3d_image_import(image_tag: str, cluster: str) {
    if shutil.which("k3d") is None {
        raise RuntimeError(
            "k3d CLI not found but kubeconfig context starts with 'k3d-'. "
            "Install k3d (https://k3d.io/) or change kubectl context."
        );
    }
    cmd: list[str] = ["k3d", "image", "import", image_tag, "-c", cluster];
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=_CLUSTER_IMAGE_LOAD_TIMEOUT_S
    );
    if result.returncode != 0 {
        raise RuntimeError(
            f"k3d image import failed (exit {result.returncode}): {result.stderr.strip()}"
        );
    }
}


"""Run `kind load docker-image <tag> --name <cluster>`."""
def run_kind_image_load(image_tag: str, cluster: str) {
    if shutil.which("kind") is None {
        raise RuntimeError(
            "kind CLI not found but kubeconfig context starts with 'kind-'. "
            "Install kind (https://kind.sigs.k8s.io/) or change kubectl context."
        );
    }
    cmd: list[str] = ["kind", "load", "docker-image", image_tag, "--name", cluster];
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=_CLUSTER_IMAGE_LOAD_TIMEOUT_S
    );
    if result.returncode != 0 {
        raise RuntimeError(
            f"kind load docker-image failed (exit {result.returncode}): {result.stderr.strip()}"
        );
    }
}


"""Read locally-stored image ID for a tag. Returns "sha256:..." or None."""
def _docker_image_id(
    image_tag: str, env_overrides: dict[str, str] | None = None
) -> str | None {
    env = dict(os.environ);
    if env_overrides {
        env.update(env_overrides);
    }
    try {
        result = subprocess.run(
            ["docker", "inspect", "--format={{.Id}}", image_tag],
            capture_output=True,
            text=True,
            timeout=_DOCKER_INSPECT_TIMEOUT_S,
            env=env
        );
    } except Exception {
        return None;
    }
    if result.returncode != 0 {
        return None;
    }
    digest = result.stdout.strip();
    if digest.startswith("sha256:") {
        return digest;
    }
    return None;
}


"""Retag `<app>:dev` with a content-derived suffix `<app>:dev-<id12>`.

K8s skips rollouts when the pod spec doesn't change; a fixed `:dev` tag
would mask new builds. Content-addressed tag forces auto-rollout on
real content change, no churn when nothing changed.

Returns new tag on success, original on docker failure (degrades to
no-auto-rollout but doesn't break deploy)."""
def _retag_with_content_id(
    base_tag: str, env_overrides: dict[str, str] | None = None
) -> str {
    image_id = _docker_image_id(base_tag, env_overrides);
    if image_id is None or not image_id.startswith("sha256:") {
        return base_tag;
    }
    short_id = image_id[len("sha256:"):][:12];
    new_tag = f"{base_tag}-{short_id}";

    env = dict(os.environ);
    if env_overrides {
        env.update(env_overrides);
    }
    try {
        result = subprocess.run(
            ["docker", "tag", base_tag, new_tag],
            capture_output=True,
            text=True,
            timeout=_DOCKER_INSPECT_TIMEOUT_S,
            env=env
        );
    } except Exception {
        return base_tag;
    }
    if result.returncode != 0 {
        return base_tag;
    }
    return new_tag;
}


"""Run `docker push <tag>` for remote-cluster deploys."""
def run_docker_push(image_tag: str) {
    cmd: list[str] = ["docker", "push", image_tag];
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=_DOCKER_PUSH_TIMEOUT_S
    );
    if result.returncode != 0 {
        tail = "\n".join((result.stdout + "\n" + result.stderr).splitlines()[-20:]);
        raise RuntimeError(
            f"docker push failed (exit {result.returncode}):\n"
            f"  cmd: {' '.join(cmd)}\n"
            f"  last 20 lines:\n{tail}\n"
            "Verify registry creds with `docker login <registry>`."
        );
    }
}


"""True if jac-client is importable. `jac build` lives in jac-client and
silently no-ops if it's missing - we'd rather error early."""
def _jac_client_installed -> bool {
    try {
        import importlib;
        importlib.import_module("jac_client");
        return True;
    } except ImportError {
        return False;
    }
}


"""Build the frontend bundle on the host (`jac build <entry>`) so docker
build can COPY .jac/client/dist/ into the gateway image. No-op if no
client.entry. Raises on actual build failure."""
def build_client_bundle(project_dir: Path, client_entry: str) -> None {
    if not client_entry {
        return;
    }
    if shutil.which("jac") is None {
        raise RuntimeError(
            "jac CLI not found but [plugins.scale.microservices.client].entry is set. "
            "Install jac or remove the client entry from jac.toml."
        );
    }
    if not _jac_client_installed() {
        raise RuntimeError(
            f"jac-client not installed but client.entry='{client_entry}' is set.\n"
            "  Fix:    pip install jac-client\n"
            "  Or:     remove [plugins.scale.microservices.client] from jac.toml"
        );
    }
    cmd: list[str] = ["jac", "build", client_entry];
    try {
        result = subprocess.run(
            cmd,
            cwd=str(project_dir),
            capture_output=True,
            text=True,
            timeout=_JAC_BUILD_TIMEOUT_S
        );
    } except subprocess.TimeoutExpired {
        raise RuntimeError(
            f"jac build {client_entry} timed out after {_JAC_BUILD_TIMEOUT_S}s. "
            "Usually <30s; check for a vite watcher loop."
        );
    }
    if result.returncode != 0 {
        tail = "\n".join((result.stdout + "\n" + result.stderr).splitlines()[-20:]);
        raise RuntimeError(
            f"jac build {client_entry} failed (exit {result.returncode}):\n"
            f"  cwd: {project_dir}\n"
            f"  last 20 lines:\n{tail}"
        );
    }
    # `jac build` can exit 0 without producing a bundle in some failure
    # modes - guard against silently shipping an image with no FE.
    dist_index = project_dir / ".jac" / "client" / "dist" / "index.html";
    if not dist_index.is_file() {
        raise RuntimeError(
            f"jac build {client_entry} exit 0 but no bundle at {dist_index}.\n"
            f"  - Verify: jac build {client_entry}\n"
            "  - Reinstall: pip install --force-reinstall jac-client"
        );
    }
}


"""Read [plugins.scale.microservices.client].entry from jac.toml; '' if absent."""
def _read_client_entry -> str {
    try {
        import from jac_scale.config_loader { get_scale_config }
        ms = get_scale_config().get_microservices_config();
        client = ms.get("client", {});
        return str(client.get("entry", "")).strip();
    } except Exception {
        return "";
    }
}


"""Build user app image, distribute to cluster, return final image tag.

`registry_url` is required for remote clusters, ignored for local."""
def auto_build_and_distribute(
    app_name: str, project_dir: Path, registry_url: str | None = None
) -> str {
    cluster_type = detect_cluster_type();

    if cluster_type == CLUSTER_UNKNOWN {
        raise RuntimeError(
            "Could not detect K8s cluster type. Set up kubectl context:\n"
            "  - Local:  minikube start  (or k3d / kind)\n"
            "  - Remote: aws eks update-kubeconfig / gcloud container clusters get-credentials\n"
            "Then: kubectl cluster-info"
        );
    }

    # Build FE bundle before docker build so the image contains .jac/client/dist.
    client_entry = _read_client_entry();
    if client_entry {
        build_client_bundle(project_dir, client_entry);
    }

    (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);

    if cluster_type == CLUSTER_MINIKUBE {
        image_tag = f"{app_name}:dev";
        env_overrides = get_minikube_docker_env();
        run_docker_build(context_dir, image_tag, dockerfile, build_args, env_overrides);
        return _retag_with_content_id(image_tag, env_overrides);
    }

    if cluster_type == CLUSTER_K3D {
        image_tag = f"{app_name}:dev";
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        # Retag BEFORE import so the cluster holds the new content-addressed tag.
        image_tag = _retag_with_content_id(image_tag);
        cluster = k3d_cluster_name(_active_context_name());
        run_k3d_image_import(image_tag, cluster);
        return image_tag;
    }

    if cluster_type == CLUSTER_KIND {
        image_tag = f"{app_name}:dev";
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        image_tag = _retag_with_content_id(image_tag);
        cluster = kind_cluster_name(_active_context_name());
        run_kind_image_load(image_tag, cluster);
        return image_tag;
    }

    # CLUSTER_REMOTE
    if not registry_url {
        raise RuntimeError(
            "Remote K8s needs a registry. Add to jac.toml:\n"
            "  [plugins.scale.kubernetes]\n"
            "  image_registry = \"my-registry.example.com/myorg\"\n"
            "Or use a local cluster (minikube/k3d/kind)."
        );
    }
    registry_prefix = registry_url.rstrip("/");
    image_tag = f"{registry_prefix}/{app_name}:dev";
    run_docker_build(context_dir, image_tag, dockerfile, build_args);
    image_tag = _retag_with_content_id(image_tag);
    run_docker_push(image_tag);
    return image_tag;
}
