import logging;
import os;
import shutil;
import subprocess;
import from pathlib { Path }


glob _logger = logging.getLogger(__name__);

glob _DOCKER_BUILD_TIMEOUT_S: int = 1800,
     _DOCKER_PUSH_TIMEOUT_S: int = 600,
     _DOCKER_PROBE_TIMEOUT_S: int = 5,
     _DOCKER_INSPECT_TIMEOUT_S: int = 10,
     _CLUSTER_IMAGE_LOAD_TIMEOUT_S: int = 180,
     _JAC_BUILD_TIMEOUT_S: int = 300;

glob _EMBEDDED_DOCKERFILE: str = "FROM python:3.12-slim\n\n" "EXPOSE 8000\n",
     _EMBEDDED_DOCKERIGNORE: str = "# Auto-generated .dockerignore.\n";


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


def _warn_build_sha_unavailable(reason: str) {
    _logger.warning(
        f"JAC_BUILD_SHA unavailable ({reason}); stamping 'unknown'. "
        "Deploy from a git checkout for build identity."
    );
}


def _warn_dirty_check_failed(context_dir: Path) {
    _logger.warning(
        f"Could not verify git tree state in {context_dir}; "
        "JAC_BUILD_SHA may omit its '-dirty' suffix."
    );
}


def _git_tree_dirty(context_dir: Path) -> bool {
    try {
        result = subprocess.run(
            ["git", "-C", str(context_dir), "status", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=_DOCKER_PROBE_TIMEOUT_S
        );
    } except Exception {
        _warn_dirty_check_failed(context_dir);
        return False;
    }
    if result.returncode != 0 {
        _warn_dirty_check_failed(context_dir);
        return False;
    }
    return bool(result.stdout.strip());
}


def _compute_build_sha(context_dir: Path) -> str {
    if shutil.which("git") is None {
        _warn_build_sha_unavailable("git CLI not found");
        return "unknown";
    }
    try {
        result = subprocess.run(
            ["git", "-C", str(context_dir), "rev-parse", "--short=12", "HEAD"],
            capture_output=True,
            text=True,
            timeout=_DOCKER_PROBE_TIMEOUT_S
        );
    } except Exception {
        _warn_build_sha_unavailable(f"git rev-parse failed in {context_dir}");
        return "unknown";
    }
    if result.returncode != 0 {
        _warn_build_sha_unavailable(f"{context_dir} is not a git repository");
        return "unknown";
    }
    sha = result.stdout.strip();
    if not sha {
        _warn_build_sha_unavailable(f"empty git SHA for {context_dir}");
        return "unknown";
    }
    if _git_tree_dirty(context_dir) {
        return f"{sha}-dirty";
    }
    return sha;
}


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
    if "JAC_BUILD_SHA" not in build_args {
        cmd.append("--build-arg");
        cmd.append(f"JAC_BUILD_SHA={_compute_build_sha(context_dir)}");
    }
    cmd.append(str(context_dir));

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


def _jac_client_installed -> bool {
    try {
        import importlib;
        importlib.import_module("jaclang.runtimelib.client");
        return True;
    } except ImportError {
        return False;
    }
}


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
            f"The jaclang client framework is unavailable but client.entry='{client_entry}' is set.\n"
            "  Fix:    reinstall jaclang\n"
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
    dist_index = project_dir / ".jac" / "client" / "dist" / "index.html";
    if not dist_index.is_file() {
        raise RuntimeError(
            f"jac build {client_entry} exit 0 but no bundle at {dist_index}.\n"
            f"  - Verify: jac build {client_entry}\n"
            "  - Reinstall: pip install --force-reinstall jac-client"
        );
    }
}


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
