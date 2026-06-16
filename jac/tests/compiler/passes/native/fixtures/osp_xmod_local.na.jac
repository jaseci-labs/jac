"""Native OSP consumer fixture (issue #6642): like osp_xmod_main, but the
consumer ALSO defines its own local OSP archetype (`Bot`) whose name sorts
BEFORE the library's `Area`. Under the old deterministic-sorted-name tag scheme
this shifted every shared tag, so the library walker body dispatched on
mismatched tags and silently mis-walked (and the interim guard rejected it with
E5090). Globally-stable per-archetype tags make the library's tags and the
consumer's tags agree regardless of what else the consumer defines, so this
materializes and runs correctly.

Same graph as osp_xmod_main: a1(1) -Portal-> a2(2) -Portal-> a3(4); Counter
spawned at a1 -> seen = 7, ports = 2. `Bot` is just a tag-order perturbation."""

import from osp_xmod_lib { Area, Portal, In, Counter }

node Bot { has hp: int = 0; }

def xmod_local_na() -> dict[str, any] {
    b = Bot(hp=3);
    a1 = Area(tag=1); a2 = Area(tag=2); a3 = Area(tag=4);
    a1 +>: Portal(w=1) :+> a2;
    a2 +>: Portal(w=2) :+> a3;
    c = Counter();
    c spawn a1;
    return {"seen": c.seen, "ports": c.ports, "bot": b.hp};
}
