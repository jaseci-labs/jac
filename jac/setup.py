"""Setup script for jaclang."""

import shutil

from setuptools import setup
from setuptools.command.build_py import build_py


class _BuildPy(build_py):
    """Copy jaclang.pth into the purelib build dir so it lands in site-packages."""

    def run(self) -> None:
        super().run()
        shutil.copy2("jaclang.pth", self.build_lib)


setup(cmdclass={"build_py": _BuildPy})
