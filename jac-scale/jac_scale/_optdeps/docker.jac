"""Guarded re-exports for docker (install group: [deploy])."""

with entry {
    try {
        import docker as docker_module;
        import from docker.errors { APIError, BuildError }
        HAS_DOCKER = True;
    } except ImportError {
        docker_module = None;
        APIError = Exception;
        BuildError = Exception;
        HAS_DOCKER = False;
    }
}
