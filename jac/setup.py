"""Setup script with custom build hook for parser generation."""

import os
import sys

from setuptools import setup
from setuptools.command.build_py import build_py

# Add source directory to path for build-time imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


class BuildPyWithParser(build_py):
    """Custom build_py command that generates parsers before building."""

    def run(self) -> None:
        """Generate static parsers, then run the standard build_py."""
        from jaclang.compiler import gen_all_parsers

        gen_all_parsers()
        super().run()


setup(cmdclass={"build_py": BuildPyWithParser})
