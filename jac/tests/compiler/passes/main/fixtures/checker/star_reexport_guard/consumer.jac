"""Imports Marker through a single-segment star re-export of a guarded name.

Marker resolves only if the star-import walk follows `from provider import *`.
Without the fix, Marker is Unknown and `m.tag` raises E1032.
"""

import from reexport { Marker }

def use_marker(m: Marker) -> int {
    return m.tag;
}
