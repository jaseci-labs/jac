"""An importer of `Pickup` lowered before its consumer: its layout registry
keeps the `Pickup` layout it adopted `Entity`'s slots into."""

import from reload_base_pickup { Pickup }

def place_pickup(kind: str) -> Pickup {
    return Pickup(kind=kind);
}
