"""A node whose base lives in another module: its first two slots after the
header are the base's, and `signature` reads every field through this
module's own layout."""

import from reload_base_entity { Entity }

node Pickup(Entity) {
    has active: bool = True,
        respawn: float = 3.0,
        kind: str = "shells";
}

def signature(p: Pickup) -> int {
    return p.pos * 10000
        + int(p.yaw * 10) * 100
        + int(p.respawn) * 10
        + (1 if p.active else 0);
}
