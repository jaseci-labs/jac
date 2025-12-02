"""Jaclang setup file."""

from __future__ import annotations

from setuptools import find_packages, setup  # type: ignore


VERSION = "0.0.1"

setup(
    name="jaclang-walkerapi",
    version=VERSION,
    packages=find_packages(include=["jaclang_walkerapi", "jaclang_walkerapi.*"]),
    install_requires=[],
    package_data={
        "": ["*.ini"],
    },
    entry_points={
        "jac": ["walkerapi = jaclang_walkerapi.walkerapi:JacRuntime"],
    },
    author="Jason Mars",
    author_email="jason@mars.ninja",
    url="https://github.com/Jaseci-Labs/jaclang",
)
