"""K-track P0.5: auto-build + auto-distribute pipeline.

This is what makes `jac start --scale` "just work" without the user
needing to touch Docker. The flow:

  1. Detect cluster type from kubeconfig (_cluster_detect)
  2. Pick the right Dockerfile:
     - Developer-checkout case (cwd is inside the jaseci repo and we
       can find both `jac/` and `jac-scale/` siblings):
       use Dockerfile.microservice.ci (installs from local source)
     - End-user case (no jaseci checkout): use Dockerfile.microservice
       (installs from PyPI). Falls back to an embedded template if the
       file isn't shipped alongside jac-scale.
  3. Build with the appropriate docker context + env:
     - minikube: env points at minikube's internal docker daemon
     - k3d/kind: host docker, then `<tool> image import|load` into cluster
     - remote: host docker tagged for the configured registry, then push
  4. Return the resolved image tag for the manifest builder to use

Failure modes are surfaced as RuntimeError with concrete next steps;
P0.6's pre-hook turns those into a clean exit-1 + actionable console
message instead of a cryptic stack trace.
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


# Embedded fallback Dockerfile. Used only when neither the
# developer-checkout path nor the shipped Dockerfile.microservice is
# available. Installs jac-scale from PyPI (>= 0.2.15 has the K-track).
glob _EMBEDDED_DOCKERFILE: str = "FROM python:3.12-slim\n\n"
     "RUN apt-get update \\\n"
     "    && apt-get install -y --no-install-recommends git curl \\\n"
     "    && rm -rf /var/lib/apt/lists/*\n\n"
     "RUN pip install --no-cache-dir --upgrade pip\n\n"
     "RUN pip install --no-cache-dir \"jac-scale[deploy]>=0.2.15\"\n\n"
     "WORKDIR /app\n"
     "COPY . /app\n\n"
     "# Best-effort .jac precompile; runtime path handles anything that fails.\n"
     "RUN find . -name \"*.jac\" -not -path \"*/.jac/*\" -not -path \"*/__jac_gen__/*\" \\\n"
     "        -exec jac tool jac2py {} + 2>/dev/null || true\n\n"
     "EXPOSE 8000\n";


"""Find the jaseci repo root by walking up from `start`.

A repo root is identified by having both `jac/` and `jac-scale/` sibling
directories. Returns the Path or None if not found within MAX_LEVELS
parent traversals.

Used to detect the developer-checkout case so the auto-build can use the
local-source Dockerfile (Dockerfile.microservice.ci) instead of the
PyPI-installing one.
"""
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


"""Locate the Dockerfile.microservice shipped alongside the jac-scale package.

Returns the Path or None if not found. The shipped file lives at
`<jac-scale-package-dir>/../scripts/Dockerfile.microservice` (i.e. the
`scripts/` sibling of the Python package). Extracted as a separate
function so unit tests can mock it without touching the import system.
"""
def find_shipped_dockerfile -> Path | None {
    try {
        import jac_scale;
        pkg_dir = Path(jac_scale.__file__).parent;
        shipped = pkg_dir.parent / "scripts" / "Dockerfile.microservice";
        if shipped.is_file() {
            return shipped;
        }
    } except Exception {
        pass;
    }
    return None;
}


"""Pick the right (Dockerfile path, build context, build args) tuple.

Returns a tuple (dockerfile, context_dir, build_args) where:
  - dockerfile: Path to use with docker build -f
  - context_dir: Path to use as docker build's positional context arg
  - build_args: dict of --build-arg key=value pairs

Decision order:
  1. User-provided <project_dir>/Dockerfile.microservice -> use it,
     context = project_dir.
  2. Developer checkout detected -> use repo-root Dockerfile.microservice.ci,
     context = repo-root, build_arg PROJECT_PATH = relative path.
  3. Shipped <jac-scale package>/scripts/Dockerfile.microservice -> use it,
     context = project_dir.
  4. Embedded fallback -> write to <project_dir>/.jac/Dockerfile.gen,
     context = project_dir.
"""
def resolve_dockerfile(project_dir: Path) -> tuple[Path, Path, dict[str, str]] {
    # 1. User override
    user_dockerfile = project_dir / "Dockerfile.microservice";
    if user_dockerfile.is_file() {
        return (user_dockerfile, project_dir, {});
    }

    # 2. Developer checkout - use Dockerfile.microservice.ci with repo root
    repo_root = find_jaseci_repo_root(project_dir);
    if repo_root {
        ci_dockerfile = repo_root / "jac-scale" / "scripts" / "Dockerfile.microservice.ci";
        if ci_dockerfile.is_file() {
            try {
                rel_project = str(
                    project_dir.resolve().relative_to(repo_root.resolve())
                );
            } except ValueError {
                # project_dir not inside repo_root - shouldn't happen given
                # find_jaseci_repo_root walks up FROM project_dir, but be safe.
                rel_project = "";
            }
            return (
                ci_dockerfile,
                repo_root,
                {"PROJECT_PATH": rel_project} if rel_project else {}
            );
        }
    }

    # 3. Shipped Dockerfile.microservice (PyPI install path)
    shipped = find_shipped_dockerfile();
    if shipped is not None {
        return (shipped, project_dir, {});
    }

    # 4. Embedded fallback - write out and use it
    cache_dir = project_dir / ".jac";
    cache_dir.mkdir(parents=True, exist_ok=True);
    generated = cache_dir / "Dockerfile.gen";
    generated.write_text(_EMBEDDED_DOCKERFILE);
    return (generated, project_dir, {});
}


"""Run `docker build` with optional env override and build args.

`env_overrides` lets the caller redirect Docker at a different daemon
(minikube's internal one). On failure raises RuntimeError with the last
30 lines of stderr — gives the user the actual reason without dumping
hundreds of lines of pip/apt output.
"""
def run_docker_build(
    context_dir: Path,
    image_tag: str,
    dockerfile_path: Path,
    build_args: dict[str, str],
    env_overrides: dict[str, str] | None = None
) {
    if shutil.which("docker") is None {
        raise RuntimeError(
            "docker CLI not found in PATH. Install Docker Desktop "
            "(https://docs.docker.com/get-docker/) or another Docker-"
            "compatible runtime, then retry."
        );
    }

    env = dict(os.environ);
    if env_overrides {
        env.update(env_overrides);
    }

    cmd: list[str] = ["docker", "build", "-t", image_tag, "-f", str(dockerfile_path)];
    for (key, value) in build_args.items() {
        cmd.append("--build-arg");
        cmd.append(f"{key}={value}");
    }
    cmd.append(str(context_dir));

    try {
        result = subprocess.run(
            cmd, env=env, capture_output=True, text=True, timeout=600
        );
    } except subprocess.TimeoutExpired {
        raise RuntimeError(
            f"docker build timed out after 600s. The build context "
            f"({context_dir}) might be too large; check with "
            f"`du -sh` and consider adding a .dockerignore."
        );
    }

    if result.returncode != 0 {
        # Combine stdout + stderr for the failure trace; docker buildkit
        # writes progress to stderr but real errors land in either stream.
        combined = (result.stdout + "\n" + result.stderr).strip();
        tail = "\n".join(combined.splitlines()[-30:]);
        raise RuntimeError(
            f"docker build failed (exit {result.returncode}):\n"
            f"  cmd: {' '.join(cmd)}\n"
            f"  last 30 lines of output:\n{tail}"
        );
    }
}


"""Run `k3d image import <tag> -c <cluster>` to load a host-built image."""
def run_k3d_image_import(image_tag: str, cluster: str) {
    if shutil.which("k3d") is None {
        raise RuntimeError(
            "k3d CLI not found in PATH but kubeconfig context starts with "
            "'k3d-'. Install k3d (https://k3d.io/) or change kubectl "
            "context."
        );
    }
    cmd: list[str] = ["k3d", "image", "import", image_tag, "-c", cluster];
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180);
    if result.returncode != 0 {
        raise RuntimeError(
            f"k3d image import failed (exit {result.returncode}): "
            f"{result.stderr.strip()}"
        );
    }
}


"""Run `kind load docker-image <tag> --name <cluster>` to load an image."""
def run_kind_image_load(image_tag: str, cluster: str) {
    if shutil.which("kind") is None {
        raise RuntimeError(
            "kind CLI not found in PATH but kubeconfig context starts with "
            "'kind-'. Install kind (https://kind.sigs.k8s.io/) or change "
            "kubectl context."
        );
    }
    cmd: list[str] = ["kind", "load", "docker-image", image_tag, "--name", cluster];
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180);
    if result.returncode != 0 {
        raise RuntimeError(
            f"kind load docker-image failed (exit {result.returncode}): "
            f"{result.stderr.strip()}"
        );
    }
}


"""Run `docker push <tag>` for remote-cluster deploys."""
def run_docker_push(image_tag: str) {
    cmd: list[str] = ["docker", "push", image_tag];
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600);
    if result.returncode != 0 {
        tail = "\n".join((result.stdout + "\n" + result.stderr).splitlines()[-20:]);
        raise RuntimeError(
            f"docker push failed (exit {result.returncode}):\n"
            f"  cmd: {' '.join(cmd)}\n"
            f"  last 20 lines:\n{tail}\n"
            f"Verify your registry credentials with `docker login "
            f"<registry>`."
        );
    }
}


"""Top-level entry: build the user's app image and load it into the cluster.

`app_name` becomes the image-name component (e.g. "myapp" -> "myapp:dev").
`project_dir` is the directory with jac.toml + the .jac files.
`registry_url` is the optional registry prefix from
[plugins.scale.kubernetes].image_registry; required for remote clusters,
ignored for local ones (minikube/k3d/kind handle distribution natively).

Returns the fully-qualified image tag the K8s manifests should reference.
"""
def auto_build_and_distribute(
    app_name: str, project_dir: Path, registry_url: str | None = None
) -> str {
    cluster_type = detect_cluster_type();

    if cluster_type == CLUSTER_UNKNOWN {
        raise RuntimeError(
            "Could not detect K8s cluster type from kubeconfig.\n"
            "Auto-build needs an active kubectl context. Try:\n"
            "  - Local:  minikube start  (or k3d / kind)\n"
            "  - Remote: aws eks update-kubeconfig / "
            "gcloud container clusters get-credentials\n"
            "Then verify with: kubectl cluster-info"
        );
    }

    (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);

    if cluster_type == CLUSTER_MINIKUBE {
        # Build inside minikube's internal docker daemon - image lands
        # directly where the cluster can pull it (no registry needed).
        image_tag = f"{app_name}:dev";
        env_overrides = get_minikube_docker_env();
        run_docker_build(context_dir, image_tag, dockerfile, build_args, env_overrides);
        return image_tag;
    }

    if cluster_type == CLUSTER_K3D {
        image_tag = f"{app_name}:dev";
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        cluster = k3d_cluster_name(_active_context_name());
        run_k3d_image_import(image_tag, cluster);
        return image_tag;
    }

    if cluster_type == CLUSTER_KIND {
        image_tag = f"{app_name}:dev";
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        cluster = kind_cluster_name(_active_context_name());
        run_kind_image_load(image_tag, cluster);
        return image_tag;
    }

    # cluster_type == CLUSTER_REMOTE
    if not registry_url {
        raise RuntimeError(
            "Remote K8s cluster needs a registry the cluster can pull from.\n"
            "Add to your jac.toml:\n"
            "  [plugins.scale.kubernetes]\n"
            "  image_registry = \"my-registry.example.com/myorg\"\n"
            "Or use a local cluster (minikube / k3d / kind) where auto-build\n"
            "loads images directly into the cluster without a registry."
        );
    }
    registry_prefix = registry_url.rstrip("/");
    image_tag = f"{registry_prefix}/{app_name}:dev";
    run_docker_build(context_dir, image_tag, dockerfile, build_args);
    run_docker_push(image_tag);
    return image_tag;
}
