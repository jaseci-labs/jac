"""Visit owned and borrowed pointer lists through the boxed OSP target ABI."""

node Area {
    has tag: int = 1;
}

node Hub {}

walker Flood {
    has count: int = 0;

    can flood with Area entry {
        self.count += here.tag;
        neighbors = [here-->];
        for i in range(len(neighbors)) {
            visit [neighbors[i]];
        }
    }
}

walker FieldTour {
    has targets: list[Area] = [],
        count: int = 0;

    can start with Hub entry {
        visit self.targets;
    }

    can at_area with Area entry {
        self.count += here.tag;
    }
}

def indexed_visits(repeats: int) -> int {
    first = Area(tag=1);
    first ++> Area(tag=2);
    total = 0;
    for i in range(repeats) {
        tour = first spawn Flood();
        total += tour.count;
    }
    return total;
}

def borrowed_visits(repeats: int) -> int {
    targets = [Area(tag=4), Area(tag=8)];
    hub = Hub();
    total = 0;
    for i in range(repeats) {
        tour = hub spawn FieldTour(targets=targets);
        total += tour.count;
    }
    # Both the borrowed list and its elements must survive all visits.
    return total + len(targets) + targets[0].tag + targets[1].tag;
}
