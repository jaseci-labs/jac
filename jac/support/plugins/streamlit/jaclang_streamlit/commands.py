"""Module for registering Streamlit plugin."""

import os
import sys
import tempfile

from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl

import streamlit.web.bootstrap as bootstrap

class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def streamlit(filename: str) -> None:
            """Streamlit the specified .jac file.

            :param filename: The path to the .jac file.
            """
            if filename.endswith(".jac"):
                abs_path = os.path.abspath(filename)
                dirname, basename = os.path.split(abs_path)
                basename = basename.replace(".jac", "")
                assert (
                    basename not in sys.modules
                ), "Please use another name for the .jac file. It conflicts with a Python package."
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
            else:
                print("Not a .jac file.")

        @cmd_registry.register
        def dot_view(filename: str) -> None:
            """View the content of a DOT file. in Streamlit Application.

            :param filename: The path to the DOT file that wants to be shown.
            """
            from jaclang.cli.cli import dot

            dot(filename)
            _, filename = os.path.split(filename)
            dot_file = os.path.abspath(f"{filename.replace('.jac', '.dot')}")
            dot_streamlit_view_file = os.path.join(
                os.path.dirname(__file__), "dot_viewer.py"
            )
            bootstrap.run(
                dot_streamlit_view_file,
                is_hello=False,
                args=[dot_file],
                flag_options={},
            )
