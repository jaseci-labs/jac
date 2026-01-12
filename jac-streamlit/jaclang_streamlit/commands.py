"""Module for registering Streamlit plugin."""

import os
import sys
import tempfile

import streamlit.web.bootstrap as bootstrap

from jaclang.cli.command import Arg, ArgKind, CommandPriority
from jaclang.cli.registry import get_registry
from jaclang.pycore.runtime import hookimpl


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""
        registry = get_registry()

        @registry.command(
            name="streamlit",
            help="Run a Jac file as a Streamlit app",
            args=[
                Arg.create(
                    "filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"
                ),
            ],
            examples=[
                ("jac streamlit myapp.jac", "Run myapp.jac as Streamlit app"),
            ],
            group="tools",
            priority=CommandPriority.PLUGIN,
            source="jac-streamlit",
        )
        def streamlit(filename: str) -> int:
            """Streamlit the specified .jac file.

            :param filename: The path to the .jac file.
            """
            if filename.endswith(".jac"):
                abs_path = os.path.abspath(filename)
                dirname, basename = os.path.split(abs_path)
                basename = basename.replace(".jac", "")
                assert basename not in sys.modules, (
                    "Please use another name for the .jac file. It conflicts with a Python package."
                )
                py_lines = [
                    "from jaclang_streamlit import run_streamlit",
                    f'run_streamlit("{basename}", "{dirname}")',
                ]
                with tempfile.NamedTemporaryFile(
                    mode="w", suffix=".py", delete=False
                ) as temp_file:
                    file_name = temp_file.name
                    temp_file.write("\n".join(py_lines))
                bootstrap.run(file_name, is_hello=False, args=[], flag_options={})
                return 0
            else:
                print("Not a .jac file.")
                return 1

        @registry.command(
            name="dot_view",
            help="View DOT file in Streamlit app",
            args=[
                Arg.create(
                    "filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"
                ),
            ],
            examples=[
                ("jac dot_view myapp.jac", "Generate and view DOT graph"),
            ],
            group="tools",
            priority=CommandPriority.PLUGIN,
            source="jac-streamlit",
        )
        def dot_view(filename: str) -> int:
            """View the content of a DOT file in Streamlit Application.

            :param filename: The path to the DOT file that wants to be shown.
            """
            from jaclang.cli.cli import dot

            dot(filename)
            _, filename = os.path.split(filename)
            dot_file = os.path.abspath(f"{filename.replace('.jac', '.dot')}")
            dot_streamlit_view_file = os.path.join(
                os.path.dirname(__file__), "dot_viewer.jac"
            )
            bootstrap.run(
                dot_streamlit_view_file,
                is_hello=False,
                args=[dot_file],
                flag_options={},
            )
            return 0
