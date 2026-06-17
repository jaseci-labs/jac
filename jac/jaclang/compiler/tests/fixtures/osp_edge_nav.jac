"""Cross-backend OSP equivalence fixture: edge-reference NAVIGATION in every
form a real graph walk needs (issue #6642 Blocker 1). Each `[ ... ]` edge ref
is assigned to a local and measured with `len(...)`, exercising the forms in
general expression context (not only as a bare `visit` target):

  (1) `[edge here ->:Portal:->]`   typed edge  -> edge objects   (edges_only)
  (2) `[here ->:Portal:->]`        typed edge  -> neighbor nodes
  (3) `[w -->[?:Area]]`            untyped out + node-type filter, explicit origin
  (4) `[here <-:In:<-]`            incoming typed edge
  (5) `[ent ->:In:->[?:Area]]`     chained typed edge + node filter, origin = a
                                   plain `def` parameter (no `here`)

Forms 1/2/4 ride the shared `VisPass` ability and form 3 (implicit origin) the
shared `ThinkPass` ability, so they compile on every backend that runs the
walker. Forms 3 (explicit origin) and 5 live in plain `def`s, which are not
shared into native context, so the `na {}` block carries its own copies.

Graph: World --> a1, World --> a2 (untyped); a1 -Portal-> a2; e1 -In-> a1,
e2 -In-> a1. From a1: 1 portal edge, 1 portal neighbor, 2 incoming In entities;
from World: 2 areas; area_of(e1): 1 area.
"""

node World {}
node Area { has tag: int = 0; }
node Entity { has eid: int = 0; }
edge Portal { has w: int = 0; }
edge In {}

walker VisPass {
    has ports: int = 0, nbrs: int = 0, ents: int = 0;
    can flood with Area entry {
        self.ports += len([edge here ->:Portal:->]);   # (1)
        self.nbrs  += len([here ->:Portal:->]);         # (2)
        self.ents  += len([here <-:In:<-]);             # (4)
    }
}

walker ThinkPass {
    has areas: int = 0;
    can start with World entry {
        self.areas += len([here -->[?:Area]]);          # (3) implicit origin
    }
}

# --- py reference (sv runtime) ---
def area_of(ent: Entity) -> int {
    rooms = [ent ->:In:->[?:Area]];                     # (5) explicit origin in a def
    return len(rooms);
}

def world_areas(w: World) -> int {
    return len([w -->[?:Area]]);                        # (3) explicit origin
}

def edge_nav_py() -> dict[str, any] {
    w = World();
    a1 = Area(tag=1); a2 = Area(tag=2);
    e1 = Entity(eid=1); e2 = Entity(eid=2);
    w ++> a1;
    w ++> a2;
    a1 +>: Portal(w=5) :+> a2;
    e1 +>: In() :+> a1;
    e2 +>: In() :+> a1;
    vp = VisPass();
    vp spawn a1;
    tp = ThinkPass();
    tp spawn w;
    return {
        "ports": vp.ports,
        "nbrs": vp.nbrs,
        "ents": vp.ents,
        "areas": tp.areas,
        "world_areas": world_areas(w),
        "area_of": area_of(e1)
    };
}

# --- na (native LLVM) ---
na {
    def area_of_na(ent: Entity) -> int {
        rooms = [ent ->:In:->[?:Area]];
        return len(rooms);
    }

    def world_areas_na(w: World) -> int {
        return len([w -->[?:Area]]);
    }

    def edge_nav_na() -> dict[str, any] {
        w = World();
        a1 = Area(tag=1); a2 = Area(tag=2);
        e1 = Entity(eid=1); e2 = Entity(eid=2);
        w ++> a1;
        w ++> a2;
        a1 +>: Portal(w=5) :+> a2;
        e1 +>: In() :+> a1;
        e2 +>: In() :+> a1;
        vp = VisPass();
        vp spawn a1;
        tp = ThinkPass();
        tp spawn w;
        return {
            "ports": vp.ports,
            "nbrs": vp.nbrs,
            "ents": vp.ents,
            "areas": tp.areas,
            "world_areas": world_areas_na(w),
            "area_of": area_of_na(e1)
        };
    }
}
