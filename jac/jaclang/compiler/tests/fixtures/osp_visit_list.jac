"""Cross-backend OSP equivalence fixture: `visit` over LIST targets — a
walker-field list (`visit self.targets`) and an inline list literal
(`visit [self.x, self.y]`), the two forms from issue #6636 (#1).

Native used to wrap a list-valued target through `osp_wrap1` as if it were a
single location, so the kernel read a garbage `__type_tag` off the list object
itself and the binary aborted after a clean compile. A list target must be
handed to `osp_visit` whole, enqueuing its elements — matching py semantics.
"""

node Hub { has name: str = "hub"; }
node Spot { has tag: int; }

walker FieldTour {
    has targets: list[Spot] = [], count: int = 0;
    can start with Hub entry {
        visit self.targets;
    }
    can at_spot with Spot entry {
        self.count += here.tag;
    }
}

walker InlineTour {
    has x: Spot, y: Spot, count: int = 0;
    can start with Hub entry {
        visit [self.x, self.y];
    }
    can at_spot with Spot entry {
        self.count += here.tag;
    }
}

# --- py reference (sv runtime) ---
def visit_list_py() -> dict[str, any] {
    w = FieldTour(targets=[Spot(tag=1), Spot(tag=2)]);
    Hub() spawn w;
    v = InlineTour(x=Spot(tag=4), y=Spot(tag=8));
    Hub() spawn v;
    return {"field": w.count, "inline": v.count};
}

# --- na (native LLVM) ---
na {
    def visit_list_na() -> dict[str, any] {
        w = FieldTour(targets=[Spot(tag=1), Spot(tag=2)]);
        Hub() spawn w;
        v = InlineTour(x=Spot(tag=4), y=Spot(tag=8));
        Hub() spawn v;
        return {"field": w.count, "inline": v.count};
    }
}

# --- cl (ECMAScript, in-process via the kernel) ---
cl {
    def visit_list_cl() -> dict[str, any] {
        w = FieldTour(targets=[Spot(tag=1), Spot(tag=2)]);
        Hub() spawn w;
        v = InlineTour(x=Spot(tag=4), y=Spot(tag=8));
        Hub() spawn v;
        return {"field": w.count, "inline": v.count};
    }
}
