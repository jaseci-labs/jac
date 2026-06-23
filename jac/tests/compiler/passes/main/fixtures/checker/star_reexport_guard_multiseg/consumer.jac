"""Imports Marker through a multi-segment star re-export of a guarded name."""

import from reexport { Marker }

def use_marker(m: Marker) -> int {
    return m.tag;
}
