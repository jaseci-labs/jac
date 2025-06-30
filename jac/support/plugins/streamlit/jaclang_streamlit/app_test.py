"""Fork of Streamlit's AppTest for Jac."""

import os
import sys

from streamlit.testing.v1 import AppTest


class JacAppTest(AppTest):
    """Jac Streamlit App Test."""

    def __init__(self, *args: list, **kwargs: dict) -> None:
        """Initialize Jac Streamlit App Test."""
        super().__init__(*args, **kwargs)

    @classmethod
    def from_jac_file(cls, file_path: str, default_timeout: int = 60) -> AppTest:
        """Load the Streamlit app from a .jac file."""
        if file_path.endswith(".jac"):
            abs_path = os.path.abspath(file_path)
            dirname, basename = os.path.split(abs_path)
            basename = basename.replace(".jac", "")
            assert (
                basename not in sys.modules
            ), "Please use another name for the .jac file. It conflicts with a Python package."
            py_lines = [
                "from jaclang_streamlit import run_streamlit",
                f'run_streamlit("{basename}", "{dirname}")',
            ]
            return cls.from_string("\n".join(py_lines), default_timeout=default_timeout)
        else:
            print("Not a .jac file.")
