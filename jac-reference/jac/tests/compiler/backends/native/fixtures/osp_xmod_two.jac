"""Native OSP consumer importing OSP archetypes from TWO libraries (issue
#6642). r1(1) -Door-> r2(2) -Door-> r3(4); Scan (from liba) walks the chain
-> total 7; Gadget (from libb) is constructed -> power 9. Globally stable hash
tags make every module agree on each archetype's tag without coordination."""

import from osp_xmod_liba { Room, Door, Scan }
import from osp_xmod_libb { Gadget }

def xmod_two_na() -> dict[str, any] {
    g = Gadget(power=9);
    r1 = Room(tag=1); r2 = Room(tag=2); r3 = Room(tag=4);
    r1 +>: Door() :+> r2;
    r2 +>: Door() :+> r3;
    s = Scan();
    s spawn r1;
    return {"total": s.total, "power": g.power};
}
