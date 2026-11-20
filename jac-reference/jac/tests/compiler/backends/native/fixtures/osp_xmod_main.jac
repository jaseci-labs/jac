"""Native OSP consumer fixture (issue #6642 Blocker 2): wires the graph and
spawns the walker, all on archetypes IMPORTED from `osp_xmod_lib` -- the normal
separation of a real codebase (structure in one module, construction + the walk
in another). Every OSP op here crosses the module boundary.

a1(tag=1) -Portal-> a2(tag=2) -Portal-> a3(tag=4). Counter spawned at a1 walks
the portal chain: seen = 1+2+4 = 7, ports = one per non-sink area = 2. The same
program on the @sv pathway returns {"seen": 7, "ports": 2}."""

import from osp_xmod_lib { Area, Portal, In, Counter }

def xmod_na() -> dict[str, any] {
    a1 = Area(tag=1); a2 = Area(tag=2); a3 = Area(tag=4);
    a1 +>: Portal(w=1) :+> a2;
    a2 +>: Portal(w=2) :+> a3;
    c = Counter();
    c spawn a1;
    return {"seen": c.seen, "ports": c.ports};
}
