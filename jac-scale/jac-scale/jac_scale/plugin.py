"""File covering plugin implementation."""

from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def scale(code_folder: str, implementation_type: str) -> None:
            """Jac Scale functionality."""
            print(
                f"Jac learner lets scale your application! lets implement your application using {implementation_type}"
            )

        @cmd_registry.register
        def destroy() -> None:
            """Jac Destroys functionality."""
            print("Hello, Jac learner lets stop your application!")
