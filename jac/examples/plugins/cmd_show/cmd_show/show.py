import os

from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.default import hookimpl

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

        @cmd_registry.register
        def show(filename: str) -> None:
            """Display the content of a file.
            :param filename: The path to the file that wants to be shown.
            """
            if not os.path.exists(filename):
                print(f"File '{filename}' not found.")
                return

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

            with open(filename) as file:
                content = file.read()

            formatter = TerminalFormatter()

            highlighted_content = pygments.highlight(content, lexer, formatter)
            print(highlighted_content)
