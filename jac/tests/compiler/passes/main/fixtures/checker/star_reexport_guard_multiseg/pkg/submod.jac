"""Deep submodule provider for the multi-segment star re-export regression.

`Marker` is guarded (inside an `if`) so it never lands in the module's
top-level names, which keeps it out of the eager star expansion and forces
resolution through the star-import walk (_resolve_star_import_symbol).
"""

import sys;
with entry {
    if (sys.platform != "") {
        class Marker {
            def init(self: Marker, tag: int = 0) -> None {
                self.tag = tag;
            }
        }
    }
}
