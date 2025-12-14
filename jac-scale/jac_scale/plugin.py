"""File covering plugin implementation."""

import os
import pathlib
import pickle
import sys

from dotenv import load_dotenv

from jaclang.cli.cmdreg import CommandPriority, cmd_registry
from jaclang.pycore.runtime import (
    ExecutionContext,
    hookimpl,
    plugin_manager,
)
from jaclang.pycore.runtime import (
    JacRuntime as Jac,
)

from .context import JScaleExecutionContext
from .kubernetes.docker_impl import build_and_push_docker
from .kubernetes.k8 import deploy_k8
from .kubernetes.utils import cleanup_k8_resources
from .serve import JacAPIServer


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def scale(file_path: str, build: bool = False) -> None:
            """Jac Scale functionality."""

            if not os.path.exists(file_path):
                raise FileNotFoundError(f"File not found: '{file_path}'")
            code_folder = os.path.dirname(file_path) or "."
            dotenv_path = os.path.join(code_folder, ".env")
            load_dotenv(dotenv_path)
            code_folder = os.path.relpath(code_folder)
            code_folder = pathlib.Path(code_folder).as_posix()
            base_file_path = os.path.basename(file_path)
            if build:
                build_and_push_docker(code_folder)
            deploy_k8(code_folder, base_file_path, build)

        @cmd_registry.register
        def destroy(file_path: str) -> None:
            """Jac Destroys functionality."""

            if not os.path.exists(file_path):
                raise FileNotFoundError(f"File not found: '{file_path}'")
            code_folder = os.path.dirname(file_path) or "."
            dotenv_path = os.path.join(code_folder, ".env")
            load_dotenv(dotenv_path)
            cleanup_k8_resources()

        @cmd_registry.register(priority=CommandPriority.PLUGIN, source="jac-scale")
        def serve(
            filename: str,
            session: str = "",
            port: int = 8000,
            main: bool = True,
            faux: bool = False,
        ) -> None:
            """Start a REST API server for the specified .jac file.

            Executes the target module and turns all functions into authenticated REST API
            endpoints. Function signatures are introspected to create the API interface.
            Walkers are converted to REST APIs where their fields become the interface,
            with an additional target_node field for spawning location.

            Each user gets their own persistent root node that persists across runs.
            Users must create an account and authenticate to access the API.

            Args:
                filename: Path to the .jac file to serve
                session: Session identifier for persistent state (default: auto-generated)
                port: Port to run the server on (default: 8000)
                main: Treat the module as __main__ (default: True)
                faux: Perform introspection and print endpoint docs without starting server (default: False)

            Examples:
                jac serve myprogram.jac
                jac serve myprogram.jac --port 8080
                jac serve myprogram.jac --session myapp.session
                jac serve myprogram.jac --faux
            """

            # Process file and session
            from jaclang.cli.cli import proc_file_sess

            base, mod, mach = proc_file_sess(filename, session)
            lng = filename.split(".")[-1]
            Jac.set_base_path(base)

            # Import the module
            if filename.endswith((".jac", ".py")):
                try:
                    Jac.jac_import(
                        target=mod,
                        base_path=base,
                        lng=lng,
                    )
                except Exception as e:
                    print(f"Error loading {filename}: {e}", file=sys.stderr)
                    mach.close()
                    exit(1)
            elif filename.endswith(".jir"):
                try:
                    with open(filename, "rb") as f:
                        Jac.attach_program(pickle.load(f))
                        Jac.jac_import(
                            target=mod,
                            base_path=base,
                            lng=lng,
                        )
                except Exception as e:
                    print(f"Error loading {filename}: {e}", file=sys.stderr)
                    mach.close()
                    exit(1)

            # Create and start the API server
            # Use session path for persistent storage across user sessions
            session_path = session if session else os.path.join(base, f"{mod}.session")

            server = JacAPIServer(
                module_name=mod,
                session_path=session_path,
                port=port,
                base_path=base,
            )

            # If faux mode, print endpoint documentation and exit
            if faux:
                try:
                    server.print_endpoint_docs()
                    mach.close()
                    return
                except Exception as e:
                    print(
                        f"Error generating endpoint documentation: {e}", file=sys.stderr
                    )
                    mach.close()
                    exit(1)

            # Don't close the context - keep the module loaded for the server
            # mach.close()

            try:
                server.start()
            except KeyboardInterrupt:
                print("\nServer stopped.")
                mach.close()  # Close on shutdown
            except Exception as e:
                print(f"Server error: {e}", file=sys.stderr)
                mach.close()
                exit(1)


# Plugin implementation for overriding JacRuntime hooks
class JacScalePlugin:
    """Jac Scale Plugin Implementation."""

    @staticmethod
    @hookimpl
    def create_j_context(
        session: str | None = None, root: str | None = None
    ) -> ExecutionContext:
        return JScaleExecutionContext(session=session, root=root)


# Register the plugin
plugin_manager.register(JacScalePlugin())
