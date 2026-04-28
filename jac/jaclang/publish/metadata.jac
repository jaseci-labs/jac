"""METADATA 2.4 string generator for jac publish — in-memory, nothing written to disk."""

import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig, PersonConfig }

glob METADATA_VERSION: str = "2.4";

"""Normalize a package name per PEP 503/625 (lowercase, collapse hyphens/underscores/dots)."""
def normalize_package_name(name: str) -> str;

"""Build an RFC 5322 Author-email / Maintainer-email header value from a PersonConfig list."""
def build_person_header(persons: list[PersonConfig]) -> str;

"""Normalise a version constraint (npm caret/tilde or PEP 440) to a pip-compatible specifier string."""
def normalize_constraint(raw: str) -> str;

"""Build a Requires-Dist value; appends '; extra == "group"' marker when extra is given."""
def build_requires_dist(name: str, raw_ver: str, extra: str | None = None) -> str;

"""Return the Description-Content-Type for a README filename (.md, .rst, or plain text)."""
def readme_content_type(readme_filename: str) -> str;

"""Generate a complete METADATA 2.4 string from a JacConfig; raises ValueError when config.package is None."""
def generate_metadata(config: JacConfig, project_root: Path | None = None) -> str;

"""Parse a METADATA string into dict[header → [values]]; body stored under 'body' key."""
def parse_metadata(text: str) -> dict[str, list[str]];
