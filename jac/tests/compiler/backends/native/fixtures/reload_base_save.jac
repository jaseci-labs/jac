"""Reaches `Pickup` through `reload_base_level` before its defining module,
and writes only the fields `Pickup` declares itself."""

import from reload_base_level { place_pickup }
import from reload_base_pickup { Pickup, signature }

def deactivate(p: Pickup) {
    p.active = False;
    p.respawn = 9.0;
}

def deactivate_probe -> int {
    p = place_pickup("rockets");
    deactivate(p);
    return signature(p);
}
