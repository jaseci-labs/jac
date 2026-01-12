import os

from jaclang.cli.registry import get_registry
from jaclang.cli.command import Arg, ArgKind, CommandPriority
from jaclang.pycore.runtime import hookimpl

import pygments
from pygments.formatters import TerminalFormatter
from pygments.lexers import TextLexer, get_lexer_for_filename
from pygments.util import ClassNotFound

# from jac-highlighter.jac_syntax_highlighter import JacLexer


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Creating Jac CLI cmds."""
        registry = get_registry()

        @registry.command(
            name="show",
            help="Display file contents with syntax highlighting",
            args=[
                Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to file to display"),
            ],
            examples=[
                ("jac show myfile.jac", "Display Jac file with highlighting"),
                ("jac show script.py", "Display Python file with highlighting"),
            ],
            group="tools",
            priority=CommandPriority.PLUGIN,
            source="cmd-show"
        )
        def show(filename: str) -> int:
            """Display the content of a file with syntax highlighting.
            :param filename: The path to the file that wants to be shown.
            """
            if not os.path.exists(filename):
                print(f"File '{filename}' not found.")
                return 1

            # ext = os.path.splitext(filename)[1]
            # if ext == ".jac":
            #     lexer = JacLexer()
            # else:
            try:
                lexer = get_lexer_for_filename(filename)
            except ClassNotFound:
                lexer = TextLexer()
            except Exception as e:
                print(f"An error occurred: {e}")
                return 1

            with open(filename) as file:
                content = file.read()

            formatter = TerminalFormatter()

            highlighted_content = pygments.highlight(content, lexer, formatter)
            print(highlighted_content)
            return 0
