"""User archetypes named like the OSP kernel's former internal types.

The native OSP kernel is compiled into the same program as user code, and the
native backend registers archetypes in one namespace. These declarations reuse
every name the kernel once used for its own records, each with a layout that
differs from the kernel record, while a walker traverses typed edges so the
kernel's descriptors, scopes, frames and adjacency rows are all built.
"""

obj Slot {
    has path: list[int] = [],
        label: str = "";
}

obj Plan {
    has steps: list[str] = [];
}

obj WalkerDesc {
    has ratio: float = 0.5;
}

obj NodeDesc {
    has names: list[str] = [];
}

obj Frame {
    has depth: int = 0,
        title: str = "";
}

obj WalkScope {
    has marks: dict[int, int] = {};
}

obj Adj {
    has weight: float = 1.0;
}

obj EdgeRow {
    has cells: list[float] = [];
}

obj EdgeTypeDesc {
    has note: str = "";
}

node Stop {
    has value: int = 0;
}

edge Road: Stop --> Stop {
    has toll: int = 0;
}

walker Tour {
    has total: int = 0,
        tolls: int = 0,
        seen: list[Slot] = [];

    can arrive with Stop entry {
        self.total += here.value;
        self.seen.append(Slot(path=[here.value], label="stop"));
        roads = [edge here->:Road:->];
        for road in roads {
            self.tolls += road.toll;
        }
        visit [here->:Road:->];
    }
}

def tour_total -> int {
    first = Stop(value=1);
    second = Stop(value=10);
    third = Stop(value=100);
    first +>:Road(toll=2):+> second;
    second +>:Road(toll=3):+> third;
    walk = first spawn Tour();
    return walk.total + walk.tolls * 1000 + len(walk.seen) * 100000;
}

def shadow_records -> int {
    slot = Slot(path=[4, 5, 6], label="slot");
    plan = Plan(steps=["a", "b"]);
    wd = WalkerDesc(ratio=0.25);
    nd = NodeDesc(names=["x"]);
    frame = Frame(depth=7, title="frame");
    scope = WalkScope(marks={1: 2});
    adj = Adj(weight=2.0);
    row = EdgeRow(cells=[1.0, 2.0]);
    desc = EdgeTypeDesc(note="edge");
    total = len(slot.path) + len(plan.steps) + len(nd.names) + frame.depth;
    total += scope.marks[1] + len(row.cells) + len(desc.note) + len(slot.label);
    if wd.ratio == 0.25 and adj.weight == 2.0 {
        total += 1000;
    }
    return total;
}
