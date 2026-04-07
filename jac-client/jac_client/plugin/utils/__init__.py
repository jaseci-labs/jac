"""Utility modules for jac-client plugin."""

import jaclang  # noqa: F401 — registers JacMetaImporter for .jac files
from jac_client.plugin.utils.bun_installer import (
    ensure_bun_available,
    prompt_install_bun,
)
from jac_client.plugin.utils.client_deps import ensure_client_deps

__all__ = [
    "ensure_bun_available",
    "prompt_install_bun",
    "ensure_client_deps",
]
