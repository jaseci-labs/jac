"""Cross-backend OSP equivalence fixture: edge disconnect via `del e` (issue
#6642 Blocker 3). `move_to_area` rewires an entity's `In` edge by deleting the
old edge(s) and connecting the new area; the result is read back through edge
refs (Blocker 1), so this also pins that disconnect actually removes the edge
from the adjacency rather than silently no-oping.

Entity starts In a1; after move_to_area(e, a2) it has exactly one outgoing In
edge (the old one was removed, not left behind). Plain `def`s are not shared
into native context, so the `na {}` block carries its own copies.
"""

node Area { has tag: int = 0; }
node Entity { has eid: int = 0; }
edge In {}

# --- py reference (sv runtime) ---
def move_to_area(ent: Entity, new_area: Area) {
    olds = [edge ent ->:In:->];
    for e in olds {
        del e;
    }
    ent +>: In() :+> new_area;
}

def ent_area_count(ent: Entity) -> int {
    return len([ent ->:In:->[?:Area]]);
}

def edge_del_py() -> dict[str, any] {
    a1 = Area(tag=1); a2 = Area(tag=2);
    e = Entity(eid=7);
    e +>: In() :+> a1;
    before = len([edge e ->:In:->]);
    move_to_area(e, a2);
    after_edges = len([edge e ->:In:->]);
    return {"before": before, "after_edges": after_edges, "now_in": ent_area_count(e)};
}

# --- na (native LLVM) ---
na {
    def move_to_area_na(ent: Entity, new_area: Area) {
        olds = [edge ent ->:In:->];
        for e in olds {
            del e;
        }
        ent +>: In() :+> new_area;
    }

    def ent_area_count_na(ent: Entity) -> int {
        return len([ent ->:In:->[?:Area]]);
    }

    def edge_del_na() -> dict[str, any] {
        a1 = Area(tag=1); a2 = Area(tag=2);
        e = Entity(eid=7);
        e +>: In() :+> a1;
        before = len([edge e ->:In:->]);
        move_to_area_na(e, a2);
        after_edges = len([edge e ->:In:->]);
        return {
            "before": before,
            "after_edges": after_edges,
            "now_in": ent_area_count_na(e)
        };
    }
}
