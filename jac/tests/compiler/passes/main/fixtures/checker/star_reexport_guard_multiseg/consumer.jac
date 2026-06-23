"""Imports Marker through a multi-segment star re-export of a guarded name.

Marker resolves only if the star-import walk follows `include pkg.submod;`
and loads the resolved file directly. With the buggy extension-probing,
Marker is Unknown and `m.tag` raises E1032.
"""

import from reexport { Marker }

def use_marker(m: Marker) -> int {
    return m.tag;
}
