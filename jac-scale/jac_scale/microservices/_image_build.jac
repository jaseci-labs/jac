"""Auto-build + auto-distribute pipeline for `jac start --scale`.

Makes `jac start --scale` "just work" without the user needing to
touch Docker. The flow:

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
the plugin's pre-hook turns those into a clean exit-1 + actionable
console message instead of a cryptic stack trace.
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


# Subprocess timeouts (seconds). Centralized so future tuning (e.g.
# slow CI runners needing 1.5x docker build time) is a single edit.
# `_DOCKER_BUILD_TIMEOUT_S` is the largest because first-time minikube
# builds download apt + pip from scratch inside the cluster's daemon.
glob _DOCKER_BUILD_TIMEOUT_S: int = 1800,
     _DOCKER_PUSH_TIMEOUT_S: int = 600,
     _DOCKER_PROBE_TIMEOUT_S: int = 5,
     _DOCKER_INSPECT_TIMEOUT_S: int = 10,
     _CLUSTER_IMAGE_LOAD_TIMEOUT_S: int = 180,
     _JAC_BUILD_TIMEOUT_S: int = 300;


# Embedded fallback Dockerfile. Used only when neither the
# developer-checkout path nor the shipped Dockerfile.microservice is
# available. Installs jac-scale from PyPI (>= 0.2.15 has microservice mode).
glob _EMBEDDED_DOCKERFILE: str = "FROM python:3.12-slim\n\n"
     "RUN apt-get update \\\n"
     "    && apt-get install -y --no-install-recommends git curl \\\n"
     "    && rm -rf /var/lib/apt/lists/*\n\n"
     "# safe.directory: shared volumes (EFS, etc.) commonly land in\n"
     "# the pod with a UID that doesn't match the running process,\n"
     "# tripping git's CVE-2022-24765 ownership check. No-op for apps\n"
     "# that don't run git on a shared mount.\n"
     "RUN git config --system --add safe.directory '*'\n\n"
     "RUN pip install --no-cache-dir --upgrade pip\n\n"
     "# jac-client provides the `jac install` subcommand used below to\n"
     "# resolve jac.toml [dependencies].\n"
     "RUN pip install --no-cache-dir \"jac-scale[deploy,data]>=0.2.15\" "
     "jac-client\n\n"
     "WORKDIR /app\n"
     "COPY . /app\n\n"
     "# Install the project's own pip deps from jac.toml.\n"
     "# Without this, apps that declare [dependencies] crash at startup\n"
     "# with \"No module named 'X'\". `|| true` keeps projects without\n"
     "# any [dependencies] from failing the build.\n"
     "RUN if [ -f jac.toml ]; then jac install || true; fi\n\n"
     "# Sanity-check the jac install (used to pre-compile .jac via\n"
     "# `jac tool jac2py` but that subcommand was removed in recent\n"
     "# releases; runtime jaclang compiles on first import anyway).\n"
     "RUN jac --version\n\n"
     "EXPOSE 8000\n",
     # Embedded .dockerignore. Written next to a build context that doesn't
     # already have one. Without this, an unsuspecting docker build can pull
     # in .git, node_modules, and per-package .jac caches and time out
     # transferring the context. Mirrors the rules at the jaseci repo root.
     _EMBEDDED_DOCKERIGNORE: str = "# Auto-generated .dockerignore. "
     "Override by committing your own .dockerignore.\n"
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
     "# Anchored - **/dist would also drop .jac/client/dist (FE bundle).\n"
     "/dist\n"
     "/build\n"
     "# Jac runtime artifacts: exclude caches + per-pod state but KEEP\n"
     "# .jac/client/dist (built before docker build, served by gateway).\n"
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
        # Best-effort lookup; failure here just means we fall through
        # to the embedded template.
        ;
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


"""Ensure a `.dockerignore` exists at the build-context root.

Without one, docker build sends the entire context tree to the daemon
before starting any layers. For a jaseci repo root that's 2GB+ of
.git + .jac caches + node_modules and the build times out. If the
context has no .dockerignore, write the embedded one. Never overwrite
a user's existing .dockerignore.

Returns True if we wrote one, False if the user already has one.
"""
def ensure_dockerignore(context_dir: Path) -> bool {
    target = context_dir / ".dockerignore";
    if target.exists() {
        return False;
    }
    try {
        target.write_text(_EMBEDDED_DOCKERIGNORE);
    } except OSError {
        # Read-only mount or similar - not fatal; build will be slower
        # but won't fail. Caller's responsibility (or just live with
        # the slow build).
        return False;
    }
    return True;
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
    # Guard against multi-GB build contexts (the most common cause of
    # mysterious "docker build timed out after 600s" reports). Writes
    # the embedded .dockerignore only if the context doesn't already
    # have one - never clobbers a user-provided file.
    ensure_dockerignore(context_dir);

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

    # --progress=plain forces docker to write step-by-step output to
    # stderr instead of the fancy auto-rewriting "interactive" view,
    # so users see real-time progress. Critical for first-time builds
    # which can take 5-15 minutes (apt install + pip install + .jac
    # precompile, all happening inside minikube's docker daemon).
    # BUT: --progress=plain is a BuildKit-only flag. The legacy docker
    # builder (e.g. Ubuntu's `docker.io` package without buildx
    # installed) rejects it with "unknown flag: --progress" before any
    # build runs. Probe for buildx; only add the flag if available.
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

    # Stream output instead of capturing. capture_output=True silenced
    # the build for up to 30 minutes which left users staring at a
    # blank terminal wondering if anything was happening. Now they see
    # apt-get progress, pip download lines, layer hashes - i.e. signs
    # of life. Trade-off: if the build fails, we don't have a captured
    # buffer to surface; the failure output is on the user's terminal
    # already. The exit code is still inspected.
    try {
        result = subprocess.run(cmd, env=env, timeout=_DOCKER_BUILD_TIMEOUT_S);
    } except subprocess.TimeoutExpired {
        raise RuntimeError(
            f"docker build timed out after {_DOCKER_BUILD_TIMEOUT_S}s. The build context "
            f"({context_dir}) is likely too large or the build is "
            f"genuinely slow (e.g. first-time minikube build downloading "
            f"apt + pip from scratch).\n"
            f"  - Verify .dockerignore is present + comprehensive: "
            f"ls {context_dir}/.dockerignore\n"
            f"  - Try running docker build manually to see where it's "
            f"stuck: docker build -f {dockerfile_path} "
            f"--progress=plain {context_dir}"
        );
    }

    if result.returncode != 0 {
        raise RuntimeError(
            f"docker build failed (exit {result.returncode}). See output "
            f"above for the actual error.\n"
            f"  cmd: {' '.join(cmd)}"
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
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=_CLUSTER_IMAGE_LOAD_TIMEOUT_S
    );
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
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=_CLUSTER_IMAGE_LOAD_TIMEOUT_S
    );
    if result.returncode != 0 {
        raise RuntimeError(
            f"kind load docker-image failed (exit {result.returncode}): "
            f"{result.stderr.strip()}"
        );
    }
}


"""Read the locally-stored image ID for a tag.

Returns "sha256:..." or None on any failure (no-op fallback). Accepts
an env override so we can talk to minikube's internal docker daemon
when the build was executed there.
"""
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


"""Retag a freshly-built image with a content-derived suffix.

K8s deployments roll only when the pod spec changes. With a fixed
`<app>:dev` tag, every `jac start --scale` rebuild produces an image
whose tag is identical to the previous one - K8s sees no spec diff,
skips the rollout, and the user's edits never reach the running pods.
The user sees "deployment applied" + "Successfully built" and assumes
fresh code is live; in practice yesterday's pod stays.

Tagging with a digest-derived suffix (`<app>:dev-<id12>`) makes the
spec content-addressed: identical content -> identical tag -> no
churn; changed content -> new tag -> automatic rolling update. The
local-cluster image distribution step (`k3d image import`, `kind load`)
re-runs against the new tag, so the cluster always has what the
manifest references.

Returns the new tag on success, the original `base_tag` on any
docker-CLI failure (we'd rather degrade to the old "no auto-rollout"
behavior than break the deploy entirely - manual `kubectl rollout
restart` still works).

`base_tag` is the tag that was just `docker build`-ed (always
`<name>:dev` or `<registry>/<name>:dev`). `env_overrides` reaches
docker's daemon (e.g. minikube). Registry prefixes are preserved:
`ghcr.io/org/app:dev` -> `ghcr.io/org/app:dev-<id>`.
"""
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
            f"Verify your registry credentials with `docker login "
            f"<registry>`."
        );
    }
}


"""Detect whether jac-client is importable.

`jac build <entry>` is contributed by the jac-client package, not jac
itself. When jac-client isn't installed, `jac build` either errors with
an unhelpful "unknown command" or (worse, depending on version) returns
exit 0 without producing any dist output. Either way, the docker image
ends up without `.jac/client/dist/` and the gateway pod serves a blank
page at /. Surface a clear, actionable message before the build runs.
"""
def _jac_client_installed -> bool {
    try {
        import importlib;
        importlib.import_module("jac_client");
        return True;
    } except ImportError {
        return False;
    }
}


"""Build the frontend bundle on the host BEFORE docker build.

Mirrors what `start_microservice_mode` does in local mode (orchestrator.jac):
runs `jac build <entry>` which produces `.jac/client/dist/`. The auto-build
docker step then COPYs the project (with the dist tree included thanks to
the dockerignore tweak that allows .jac/client/dist through). Result:
the gateway pod serves the FE at `/` after deploy, matching local-mode UX.

Building on the host (not inside the docker image) keeps the runtime
image slim - no need to ship bun/node into a python container.

`client_entry` is the path from jac.toml [...microservices.client].entry.
`project_dir` is where to run `jac build` from. Returns silently on
success; raises RuntimeError on actual build failure (timeout / non-zero
exit / jac CLI missing). Skipping the FE build is fine if no client entry
is configured - gateway just won't have anything to serve at `/`.
"""
def build_client_bundle(project_dir: Path, client_entry: str) -> None {
    if not client_entry {
        return;
    }
    if shutil.which("jac") is None {
        # Surprising in a context where _scale_pre_hook is running (jac
        # is HOW we got here), but possible if PATH was scrubbed. Warn
        # via exception so the auto-build path can decide whether to
        # continue without a FE.
        raise RuntimeError(
            "jac CLI not found in PATH but [plugins.scale.microservices."
            "client].entry is set. Either install jac or remove the client "
            "entry from jac.toml."
        );
    }
    # explicit jac-client pre-flight. Without this, a missing
    # jac-client install becomes a silent FE-skip discovered only when
    # the gateway pod serves an empty page minutes later.
    if not _jac_client_installed() {
        raise RuntimeError(
            f"jac-client is not installed but "
            f"[plugins.scale.microservices.client].entry='{client_entry}' "
            "is set in jac.toml. The frontend bundle build needs "
            "jac-client.\n"
            "  Fix:    pip install jac-client\n"
            "  Or:     remove the [plugins.scale.microservices.client] "
            "section from jac.toml if this app has no frontend."
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
            "The client build is usually <30s; if it's hanging, check for a "
            "vite watcher or infinite frontend hot-reload loop."
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
    # assert the bundle is actually where the docker COPY step
    # expects it. `jac build` can return exit 0 without producing a
    # bundle in some failure modes (cached-but-broken state, vite skip,
    # missing entry file). Without this guard the image silently ships
    # without the FE and the gateway serves a blank page - making the
    # platform feel half-broken when the real cause is one config away.
    dist_index = project_dir / ".jac" / "client" / "dist" / "index.html";
    if not dist_index.is_file() {
        raise RuntimeError(
            f"jac build {client_entry} completed (exit 0) but no FE bundle "
            f"was produced at {dist_index}. Expected "
            ".jac/client/dist/index.html after a successful build.\n"
            f"  - Verify the entry compiles: jac build {client_entry}\n"
            "  - Check the project's `.jac/client/` directory exists "
            "and is writable\n"
            "  - Reinstall jac-client: pip install --force-reinstall "
            "jac-client"
        );
    }
}


"""Resolve `[plugins.scale.microservices.client].entry` from jac.toml.

Returns the entry string ("main.jac" etc) or empty if no client config.
Reads via the typed config helper since the loader's already exposing
the client section as a dict.
"""
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

    # build the frontend bundle BEFORE docker build so the gateway
    # pod's image contains .jac/client/dist/ for static serving at /.
    # Skipped silently if no client.entry in jac.toml (LLM-only / API-only
    # apps don't have a frontend).
    client_entry = _read_client_entry();
    if client_entry {
        build_client_bundle(project_dir, client_entry);
    }

    (dockerfile, context_dir, build_args) = resolve_dockerfile(project_dir);

    if cluster_type == CLUSTER_MINIKUBE {
        # Build inside minikube's internal docker daemon - image lands
        # directly where the cluster can pull it (no registry needed).
        image_tag = f"{app_name}:dev";
        env_overrides = get_minikube_docker_env();
        run_docker_build(context_dir, image_tag, dockerfile, build_args, env_overrides);
        # retag with content-derived suffix so the manifest spec
        # changes when the image changes (forces automatic rollout).
        return _retag_with_content_id(image_tag, env_overrides);
    }

    if cluster_type == CLUSTER_K3D {
        image_tag = f"{app_name}:dev";
        run_docker_build(context_dir, image_tag, dockerfile, build_args);
        # retag BEFORE importing so the new content-addressed tag
        # is what k3d's containerd ends up holding (and what the manifest
        # references). Importing the bare `:dev` tag would let the cluster
        # keep yesterday's content under the same name.
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
    # retag with content suffix BEFORE pushing. The remote cluster
    # pulls by exact tag from the registry, so the registry must hold the
    # tag the manifest references.
    image_tag = _retag_with_content_id(image_tag);
    run_docker_push(image_tag);
    return image_tag;
}
