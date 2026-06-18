"""Build-once jac-scale base image for `--no-image` deploys.

`--scale --no-image` ships the project's source into the cluster via a
ConfigMap (see manifest_builder._build_source_configmap) rather than baking
it into a per-app image. The pods still need an image with `jac` + `jac-scale`
installed to run that source - this module provides it.

The base image carries ONLY the runtime (no user code), so it is identical
across every app and every deploy of the same jac-scale version. We build it
at most once per (version, cluster) and reuse it thereafter: the first
`--no-image` deploy pays a one-time base build, every subsequent deploy - and
every source change - is build-free (the change rides the ConfigMap).

Distribution mirrors auto_build's per-cluster strategy: minikube builds into
its own daemon via docker-env; k3d/kind build locally then import to nodes;
remote clusters build + push to a registry.
"""

import logging;
import tempfile;
import from pathlib { Path }
import from jac_scale.microservices.images.cluster_detect {
    detect_cluster_type,
    k3d_cluster_name,
    kind_cluster_name,
    _active_context_name,
    get_minikube_docker_env,
    CLUSTER_MINIKUBE,
    CLUSTER_K3D,
    CLUSTER_KIND,
    CLUSTER_REMOTE,
    CLUSTER_UNKNOWN
}
import from jac_scale.microservices.images.build_helpers {
    run_docker_build,
    run_docker_push,
    run_k3d_image_import,
    run_kind_image_load,
    _docker_image_id
}

glob _logger = logging.getLogger(__name__),
     # Runtime-only image: jac + jac-scale + jac-client, no user code. Mirrors the
     # install layer of scripts/Dockerfile.microservice but omits `COPY . /app`.
     _BASE_DOCKERFILE: str = "FROM python:3.12-slim\n\n"
     "RUN apt-get update \\\n"
     "    && apt-get install -y --no-install-recommends git curl \\\n"
     "    && rm -rf /var/lib/apt/lists/*\n\n"
     "RUN git config --system --add safe.directory '*'\n\n"
     "RUN pip install --no-cache-dir --upgrade pip \\\n"
     "    && pip install --no-cache-dir \\\n"
     "        jaclang \\\n"
     "        \"jac-scale[deploy,data,tracing]\" \\\n"
     "        jac-client\n\n"
     "WORKDIR /app\n"
     "RUN jac --version\n"
     "EXPOSE 8000\n";


"""Installed jac-scale version, used to tag the base image so an upgrade
rebuilds it. Falls back to 'latest' when metadata is unavailable."""
def _base_image_version -> str {
    try {
        import from importlib.metadata { version }
        return str(version("jac-scale"));
    } except Exception {
        return "latest";
    }
}


"""Base image tag. Prefixed with the registry for remote clusters so the
push target is well-formed; bare `jac-scale-base:<ver>` for local clusters."""
def base_image_tag(registry_url: str | None = None) -> str {
    tag = f"jac-scale-base:{_base_image_version()}";
    if registry_url {
        return f"{registry_url.rstrip('/')}/{tag}";
    }
    return tag;
}


"""Write the base Dockerfile into a fresh temp build context (no user code)
and return (context_dir, dockerfile_path)."""
def _write_base_context -> tuple[Path, Path] {
    ctx = Path(tempfile.mkdtemp(prefix="jac-scale-base-"));
    df = ctx / "Dockerfile";
    df.write_text(_BASE_DOCKERFILE);
    return (ctx, df);
}


"""Ensure a jac-scale base image is available to the active cluster and
return its tag. Builds it once per (version, cluster) and reuses it after.

`registry_url` is required for remote clusters (where the image must be
pushed somewhere the nodes can pull from) and ignored for local clusters."""
def ensure_base_image(registry_url: str | None = None, dry_run: bool = False) -> str {
    if dry_run {
        # Planning only: report the tag we *would* use without touching the
        # docker daemon or cluster.
        return base_image_tag(registry_url);
    }
    cluster_type = detect_cluster_type();
    if cluster_type == CLUSTER_UNKNOWN {
        raise RuntimeError(
            "Could not detect a Kubernetes cluster for --no-image. Set up a "
            "kubectl context first:\n"
            "  - Local:  minikube start  (or k3d / kind)\n"
            "  - Remote: aws eks update-kubeconfig / gcloud container clusters get-credentials"
        );
    }

    if cluster_type == CLUSTER_MINIKUBE {
        tag = base_image_tag();
        env = get_minikube_docker_env();
        if _docker_image_id(tag, env) {
            _logger.info(f"Reusing cached base image {tag} (minikube daemon)");
            return tag;
        }
        _logger.info(f"Building jac-scale base image {tag} (one-time, minikube)...");
        (ctx, df) = _write_base_context();
        run_docker_build(ctx, tag, df, {}, env);
        return tag;
    }

    if cluster_type == CLUSTER_K3D {
        cluster = k3d_cluster_name(_active_context_name());
        tag = base_image_tag();
        if not _docker_image_id(tag) {
            _logger.info(f"Building jac-scale base image {tag} (one-time, k3d)...");
            (ctx, df) = _write_base_context();
            run_docker_build(ctx, tag, df, {});
        } else {
            _logger.info(f"Reusing cached base image {tag} (local daemon)");
        }
        # Import is idempotent and cheap; always run so a fresh cluster gets it.
        run_k3d_image_import(tag, cluster);
        return tag;
    }

    if cluster_type == CLUSTER_KIND {
        cluster = kind_cluster_name(_active_context_name());
        tag = base_image_tag();
        if not _docker_image_id(tag) {
            _logger.info(f"Building jac-scale base image {tag} (one-time, kind)...");
            (ctx, df) = _write_base_context();
            run_docker_build(ctx, tag, df, {});
        } else {
            _logger.info(f"Reusing cached base image {tag} (local daemon)");
        }
        run_kind_image_load(tag, cluster);
        return tag;
    }

    # CLUSTER_REMOTE
    if not registry_url {
        raise RuntimeError(
            "Remote K8s with --no-image needs a registry to host the base "
            "image. Add to jac.toml:\n"
            "  [plugins.scale.kubernetes]\n"
            "  image_registry = \"my-registry.example.com/myorg\"\n"
            "Or deploy to a local cluster (minikube/k3d/kind)."
        );
    }
    tag = base_image_tag(registry_url);
    if not _docker_image_id(tag) {
        _logger.info(f"Building jac-scale base image {tag} (one-time, remote)...");
        (ctx, df) = _write_base_context();
        run_docker_build(ctx, tag, df, {});
    } else {
        _logger.info(f"Reusing cached base image {tag} (local daemon)");
    }
    # Push every deploy: a no-op when the registry already has the layers.
    run_docker_push(tag);
    return tag;
}
