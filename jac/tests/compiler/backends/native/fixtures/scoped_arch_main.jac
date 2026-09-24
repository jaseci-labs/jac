"""Two imported modules each define `node Passage`, `edge Holds`, `obj Info`
and `walker Tally` -- legal Jac, one type per module. Native lowering keys every
archetype by its name scoped to the defining module, so each module's functions
keep using their own layout, and this module tells the two apart through the
import aliases: construction, field access, `[?:T]` and `->:E:->` filters,
walker entry dispatch, `isinstance`, `__name__` and spawning."""

import from scoped_arch_routes {
    Area,
    build_routes,
    route_sum,
    route_tally,
    route_info,
    is_route_passage,
    Passage as RoutePassage,
    Holds as RouteHolds,
    Info as RouteInfo,
    Tally as RouteTally
}
import from scoped_arch_rooms {
    Room,
    build_rooms,
    rooms_desc,
    rooms_tally,
    rooms_info,
    is_room_passage,
    Passage as RoomPassage,
    Holds as RoomHolds,
    Info as RoomInfo,
    Tally as RoomTally
}

walker Survey {
    has routes: int = 0,
        doors: int = 0,
        names: list[str] = [];

    can on_area with Area entry {
        visit [here->:RouteHolds:->];
    }

    can on_room with Room entry {
        visit [here->:RoomHolds:->];
    }

    can on_route with RoutePassage entry {
        self.routes += here.kind;
        self.names.append(type(here).__name__);
    }

    can on_room_passage with RoomPassage entry {
        self.doors += here.doors;
        self.names.append(here.label);
    }
}

def classify(x: any) -> int {
    if isinstance(x, RoutePassage) {
        return 1;
    }
    if isinstance(x, RoomPassage) {
        return 2;
    }
    return 0;
}

"""Each module's own functions, on graphs they built: 7028."""
def own_route_sum -> int {
    return route_sum(build_routes());
}

"""The routes walker spawned from here: total 721 over 2 passages."""
def own_route_tally -> int {
    return route_tally(build_routes());
}

"""Both walkers spawned from this module through their aliases."""
def aliased_tallies -> int {
    t = build_routes() spawn RouteTally();
    rt = build_rooms() spawn RoomTally();
    return t.total * 1000 + len(rt.labels) * 100 + int(rt.width * 4);
}

"""One walker dispatching on both `Passage` types: 7 route kinds, 2 doors."""
def survey_both -> int {
    s = build_routes() spawn Survey();
    s2 = build_rooms() spawn Survey();
    return s.routes * 100 + s2.doors * 10 + len(s.names) + len(s2.names);
}

"""`[?:T]` on each graph, and each filter against the other's graph."""
def filters -> int {
    a = build_routes();
    r = build_rooms();
    own_routes = len([a->:RouteHolds:->][?:RoutePassage]);
    own_rooms = len([r->:RoomHolds:->][?:RoomPassage]);
    any_a: any = a;
    any_r: any = r;
    crossed = len([r->:RoomHolds:->][?:RoutePassage])
        + len([a->:RouteHolds:->][?:RoomPassage])
        + len([any_r->:RouteHolds:->])
        + len([any_a->:RoomHolds:->]);
    return own_routes * 100 + own_rooms * 10 + crossed;
}

"""`isinstance` here and in each defining module: 1, 2, 0 and the matrix."""
def instance_checks -> int {
    rp = RoutePassage(kind=1, time=2);
    lp = RoomPassage(width=3.0, label="x");
    out = classify(rp) * 100 + classify(lp) * 10 + classify(build_routes());
    matrix = [
        is_route_passage(rp),
        is_route_passage(lp),
        is_room_passage(rp),
        is_room_passage(lp)
    ];
    for (i, hit) in enumerate(matrix) {
        if hit {
            out += 1000 * (i + 1);
        }
    }
    return out;
}

"""Same-named `obj Info` with same-named methods: 8 + 2.0 + 7 + 4.0."""
def infos -> float {
    return float(route_info())
        + rooms_info()
        + float(RouteInfo(cost=3, tags=[4]).total())
        + RoomInfo(label="xy", scale=2.0).total();
}

with entry {
    a = build_routes();
    r = build_rooms();
    print("route_sum", route_sum(a));
    print("rooms_desc", rooms_desc(r));
    print("route_tally", route_tally(a));
    print("rooms_tally", rooms_tally(r));
    s = a spawn Survey();
    s2 = r spawn Survey();
    print("survey", s.routes, s.names, s2.doors, s2.names);
    print("filters", filters());
    print("instances", instance_checks());
    print(
        "names",
        RoutePassage(kind=1, time=2).__class__.__name__,
        type(RoomInfo(label="q")).__name__
    );
    print("infos", infos());
    print(
        "edges",
        [e.weight for e in [edge a->:RouteHolds:->]],
        [e.note for e in [edge r->:RoomHolds:->]]
    );
}
