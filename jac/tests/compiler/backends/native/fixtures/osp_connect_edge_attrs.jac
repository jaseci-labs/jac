node Hub {
    has id: int = 0;
}

node Spoke {
    has id: int = 0;
}

edge Link: Hub --> Spoke {
    has name: str = "",
        weight: int = 0,
        tags: list[str] = [];
}

edge Heavy(Link) {
    has mass: float = 1.5;
}

edge Finished(Link) {
    def postinit {
        self.weight += 100;
    }
}

edge Road: Hub --> Hub {
    has name: str = "",
        lanes: int = 1;
}

glob draws: int = 0;

def next_weight -> int {
    draws += 1;
    return draws * 10;
}

def first_link(hub: Hub) -> Link {
    return [edge hub->:Link:->][0];
}

def literal_attrs -> int {
    hub = Hub();
    hub +>:Link:name="alpha", weight=3:+> Spoke();
    e = first_link(hub);
    return e.weight * 10 + (1 if e.name == "alpha" else 0);
}

def variable_attrs -> int {
    hub = Hub();
    label = "beta";
    amount = 7;
    hub +>:Link:name=label, weight=amount:+> Spoke();
    e = first_link(hub);
    return e.weight * 10 + (1 if e.name == "beta" else 0);
}

def expression_attrs -> int {
    hub = Hub();
    items = ["a", "b", "c"];
    hub +>:Link:tags=items, name="ga"+"mma", weight=len(items)*2:+> Spoke();
    e = first_link(hub);
    return e.weight * 100 + len(e.tags) * 10 + (1 if e.name == "gamma" else 0);
}

def defaults_kept -> int {
    hub = Hub();
    hub +>:Link:weight=5:+> Spoke();
    e = first_link(hub);
    return e.weight * 100 + len(e.tags) * 10 + (1 if e.name == "" else 0);
}

def connect_in(hub: Hub, label: str, amount: int) {
    hub +>:Link:name=label, weight=amount:+> Spoke(id=amount);
}

def inside_function -> int {
    hub = Hub();
    connect_in(hub, "delta", 4);
    e = first_link(hub);
    return e.weight * 10 + (1 if e.name == "delta" else 0);
}

def backward_attrs -> int {
    hub = Hub();
    Spoke() <+:Link:name="back", weight=6:<+ hub;
    e = first_link(hub);
    return e.weight * 10 + (1 if e.name == "back" else 0);
}

def undirected_attrs -> int {
    a = Hub(id=1);
    b = Hub(id=2);
    a <+:Road:name="both", lanes=4:+> b;
    from_a = [edge a->:Road:->][0];
    from_b = [edge b->:Road:->][0];
    ok = 1 if from_a.name == "both" and from_b.name == "both" else 0;
    return from_a.lanes * 100 + from_b.lanes * 10 + ok;
}

walker Wire {
    has label: str;

    can wire with Hub entry {
        here +>:Link:name=self.label, weight=len(self.label):+> Spoke();
    }
}

def inside_walker_ability -> int {
    hub = Hub();
    Wire(label="walked") spawn hub;
    e = first_link(hub);
    return e.weight * 10 + (1 if e.name == "walked" else 0);
}

obj Builder {
    has weight: int = 42;

    def build(hub: Hub) {
        hub +>:Link:weight=self.weight, name="built":+> Spoke();
    }
}

def inside_method -> int {
    hub = Hub();
    Builder().build(hub);
    e = first_link(hub);
    return e.weight * 10 + (1 if e.name == "built" else 0);
}

def connect_kind(hub: Hub, kind: type[Link], label: str) {
    hub +>:kind:name=label, weight=next_weight():+> Spoke();
}

def dynamic_type_attrs -> int {
    before = draws;
    hub = Hub();
    connect_kind(hub, Link, "plain");
    connect_kind(hub, Heavy, "heavy");
    links = [edge hub->:Link:->];
    heavy = [edge hub->:Heavy:->];
    ok = 1
        if links[0].name == "plain"
            and links[1].name == "heavy"
            and heavy[0].mass == 1.5
            and links[0].weight == (before + 1) * 10
            and links[1].weight == (before + 2) * 10
        else 0;
    return (draws - before) * 10 + ok;
}

def subclass_attrs -> int {
    hub = Hub();
    hub +>:Heavy:name="heavy", mass=2.5:+> Spoke();
    e = [edge hub->:Heavy:->][0];
    return e.weight * 100 + int(e.mass * 10) + (1 if e.name == "heavy" else 0) * 1000;
}

def assigned_after_postinit -> int {
    hub = Hub();
    hub +>:Finished:weight=1:+> Spoke();
    kept = Hub();
    kept +>:Finished:name="kept":+> Spoke();
    return first_link(hub).weight * 1000 + first_link(kept).weight;
}

def instance_with_attrs -> int {
    hub = Hub();
    hub +>:Link(name="inst"):weight=9:+> Spoke();
    e = first_link(hub);
    return e.weight * 10 + (1 if e.name == "inst" else 0);
}

def repeated_connects -> int {
    hub = Hub();
    target = Spoke();
    for i in range(500) {
        hub +>:Link:name="n"+str(i), weight=i:+> target;
    }
    links = [edge hub->:Link:->];
    total = 0;
    for e in links {
        total += e.weight;
    }
    return len(links) * 1000000 + total + (1 if links[499].name == "n499" else 0);
}
