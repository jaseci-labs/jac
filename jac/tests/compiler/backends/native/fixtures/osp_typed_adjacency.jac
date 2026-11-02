"""Typed hops, visits and removals on nodes mixing many edge types.

Each function encodes the ids a traversal returns as decimal digits, so the
test pins both membership and order.
"""

node Hub {
    has id: int = 0;
}

node Item {
    has id: int = 0;
}

node Town {
    has id: int = 0;
}

edge Link: Hub --> Item {}

edge Heavy(Link) {}

edge Light(Link) {}

edge Other: Hub --> Item {}

edge Spare: Hub --> Item {}

edge Road: Town --> Town {}

edge Rail: Town --> Town {}

def digits(items: list[Item]) -> int {
    r = 0;
    for it in items {
        r = r * 10 + it.id;
    }
    return r;
}

def town_digits(towns: list[Town]) -> int {
    r = 0;
    for t in towns {
        r = r * 10 + t.id;
    }
    return r;
}

def mixed_hub -> Hub {
    hub = Hub();
    hub +>:Heavy:+> Item(id=1);
    hub +>:Other:+> Item(id=2);
    hub +>:Link:+> Item(id=3);
    hub +>:Light:+> Item(id=4);
    hub +>:Heavy:+> Item(id=5);
    hub +>:Other:+> Item(id=6);
    hub +>:Spare:+> Item(id=7);
    return hub;
}

def base_hop_merges_subtypes -> int {
    return digits([mixed_hub()->:Link:->][?:Item]);
}

def exact_hops -> int {
    hub = mixed_hub();
    return digits([hub->:Heavy:->][?:Item]) * 100000
        + digits([hub->:Other:->][?:Item]) * 1000
        + digits([hub->:Spare:->][?:Item]);
}

def untyped_hop -> int {
    return digits([mixed_hub()-->][?:Item]);
}

def removal_and_reuse -> int {
    hub = Hub();
    items: list[Item] = [];
    i = 1;
    while i <= 6 {
        it = Item(id=i);
        items.append(it);
        if i % 2 == 1 {
            hub +>:Heavy:+> it;
        } else {
            hub +>:Other:+> it;
        }
        i += 1;
    }
    hub del --> items[0];
    hub del --> items[3];
    hub +>:Light:+> Item(id=7);
    hub +>:Other:+> Item(id=8);
    hub +>:Heavy:+> Item(id=9);
    return digits([hub->:Link:->][?:Item]) * 100000
        + digits([hub->:Other:->][?:Item]) * 100
        + len([hub-->]);
}

def many_edges_one_rare -> int {
    hub = Hub();
    i = 0;
    while i < 600 {
        hub +>:Other:+> Item(id=0);
        if i % 200 == 0 {
            hub +>:Spare:+> Item(id=i // 200 + 1);
        }
        i += 1;
    }
    round = 0;
    while round < 40 {
        j = 0;
        while j < 5 {
            hub +>:Light:+> Item(id=j);
            j += 1;
        }
        for it in [hub->:Light:->][?:Item] {
            if it.id != 2 or round < 39 {
                hub del --> it;
            }
        }
        round += 1;
    }
    return digits([hub->:Spare:->][?:Item]) * 1000
        + digits([hub->:Light:->][?:Item]) * 100
        + len([hub->:Other:->]) // 100;
}

def undirected_both_ways -> int {
    t1 = Town(id=1);
    t2 = Town(id=2);
    t3 = Town(id=3);
    t4 = Town(id=4);
    t1 +>:Road:+> t2;
    t3 <+:Road:+> t1;
    t4 +>:Road:+> t1;
    t1 +>:Rail:+> t4;
    return town_digits([t1->:Road:->][?:Town]) * 100000
        + town_digits([t1<-:Road:<-][?:Town]) * 1000
        + town_digits([t3->:Road:->][?:Town]) * 100
        + town_digits([t1<-:Rail:<-][?:Town]) * 10
        + town_digits([t4<-:Rail:<-][?:Town]);
}

walker Collect {
    has seen: list[int] = [];

    can start with Hub entry {
        visit [here->:Link:->];
    }

    can take with Item entry {
        self.seen.append(here.id);
    }
}

def visit_order -> int {
    w = Collect();
    mixed_hub() spawn w;
    r = 0;
    for x in w.seen {
        r = r * 10 + x;
    }
    return r;
}

with entry {
    print(
        base_hop_merges_subtypes(),
        exact_hops(),
        untyped_hop(),
        removal_and_reuse(),
        many_edges_one_rare(),
        undirected_both_ways(),
        visit_order()
    );
}
