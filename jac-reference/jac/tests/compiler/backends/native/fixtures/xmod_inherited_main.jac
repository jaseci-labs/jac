"""Native cross-module inherited-field consumer (issue #6659 Bug 2): writes the
inherited `yaw` (plain assign) and `pitch` (augmented assign) of the imported
subtype `Player`, then reads them back. Reads of inherited fields already
worked; the writes raised `E5090: field assignment` because the inherited field
slot was not resolved through the imported MRO. The same program on the @sv
pathway returns {"yaw": 2.0, "pitch": 0.5}."""

import from xmod_inherited_lib { Entity, Player }

def inherited_na() -> dict[str, any] {
    p = Player();
    p.yaw = 2.0;
    p.pitch += 0.5;
    return {"yaw": p.yaw, "pitch": p.pitch};
}
