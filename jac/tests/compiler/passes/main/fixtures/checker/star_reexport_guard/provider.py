"""Provider for the single-segment star re-export regression.

`Marker` is defined inside an `if` block on purpose (the real bug shows up
with typeshed's `if sys.version_info ...:` guards, but any condition works).
The guard keeps `Marker` out of the importer's eager star expansion, so
resolving it has to fall back to the star-import walk
(_resolve_star_import_symbol), which is the path that used to skip
single-segment imports like `from provider import *`.

A plain version guard such as `sys.version_info >= (3, 8)` would be the most
realistic form, but ruff's UP036 rejects version blocks below the project's
minimum Python, so this uses an always-true non-version condition instead.
"""

import sys

if sys.platform != "":

    class Marker:
        def __init__(self, tag: int = 0) -> None:
            self.tag = tag
