"""Guarded re-exports for docker (install group: [deploy])."""

try:
    import docker as docker_module
    from docker.errors import APIError, BuildError

    HAS_DOCKER = True
except ImportError:
    docker_module = None
    APIError = Exception
    BuildError = Exception

    HAS_DOCKER = False
