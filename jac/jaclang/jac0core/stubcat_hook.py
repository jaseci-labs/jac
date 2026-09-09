"""Process-wide handle to the open stub catalog (pure Python, boot-safe).

The module resolver and the schedule gate are seed modules that run while
the compiler is compiling itself; they must never import the catalog package
(that import would re-enter the meta importer for the very module being
resolved). They read this hook instead; ``JacCompiler.stub_catalog`` sets it
once a catalog is open. Nothing here imports jaclang.
"""

from __future__ import annotations

import os
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from jaclang.compiler.types.stubcat.reader import StubCatalog

_ACTIVE: list[StubCatalog | None] = [None]


def active() -> StubCatalog | None:
    """The open catalog, or None (no catalog yet, or catalogs disabled)."""
    return _ACTIVE[0]


def set_active(catalog: StubCatalog | None) -> None:
    _ACTIVE[0] = catalog


def env_disabled() -> bool:
    """True inside the catalog writer: the compiler it drives must never open
    (or build) a catalog, since it is producing the one everything else uses."""
    return bool(os.environ.get("JAC_STUBCAT_BUILDING"))
