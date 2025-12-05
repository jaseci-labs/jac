"""GH Release script for byLLM."""

import tomllib

from github_release import gh_release_create

with open("pyproject.toml", "rb") as f:
    data = tomllib.load(f)

version = data["tool"]["poetry"]["version"]

gh_release_create(
    "Jaseci-Labs/jaclang",
    version,
    publish=True,
    name=f"Jaclang {version}",
    asset_pattern="dist/*",
    body="Release notes for Jaclang",
)
