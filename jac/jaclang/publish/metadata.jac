"""METADATA 2.4 string generator for jac bundle — in-memory, nothing written to disk."""

import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig, PersonConfig }

glob METADATA_VERSION: str = "2.4";

"""Normalize a package name per PEP 503/625.
   e.g. 'My_Pkg.Name' -> 'my-pkg-name', 'JAC--Lang' -> 'jac-lang' """
def normalize_package_name(name: str) -> str;

"""Convert a version constraint to a pip-compatible specifier.
   e.g. '^1.2.3' -> '>=1.2.3,<2.0.0', '~1.2' -> '>=1.2.0,<1.3.0', '*' -> '' """
def normalize_constraint(raw: str) -> str;

"""Build a Requires-Dist line.
   e.g. ('requests', '>=2.28.0') -> 'requests>=2.28.0'
        ('pytest', '*', 'dev')   -> 'pytest; extra == "dev"' """
def build_requires_dist(name: str, raw_ver: str, extra: str | None = None) -> str;

"""Generate the full METADATA 2.4 string from a JacConfig. Raises ValueError when config.package is None."""
def generate_metadata(config: JacConfig, project_root: Path | None = None) -> str;
