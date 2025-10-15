from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl

class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Creating Jac CLI cmds."""

        @cmd_registry.register
        def hello():
            """Prints Hello, World!"""
            print("Hello, World!")