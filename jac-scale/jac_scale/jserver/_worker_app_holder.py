"""App factory for uvicorn multi-worker mode.

Each uvicorn worker process calls create_app() to create its own
FastAPI app instance. Config is passed via environment variables.
"""

import os
from typing import Any


def create_app() -> Any:
    """Factory function called by each uvicorn worker to create the app."""
    module_name = os.environ.get("JAC_WORKER_MODULE", "__main__")
    base_path = os.environ.get("JAC_WORKER_BASE_PATH", os.getcwd())

    # Import and load the jac module
    from jaclang.plugin.feature import JacFeature as Jac

    Jac.jac_import(
        target=module_name,
        base_path=base_path,
        override_name="__main__"
    )

    # Create the server
    from jac_scale.serve import JacAPIServer

    server = JacAPIServer(module_name=module_name, base_path=base_path)
    return server.server.create_server()
