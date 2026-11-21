"""Managed native nodes and edges are reclaimed like other objects: a live
edge row pins both endpoints and its edge object, so a node nothing refers to
(no variable, field, list, row or queued walk) is freed at once, and a
connected subgraph when it is disconnected or destroyed. Drop hooks count
reclamation."""

glob nodes_dropped: int = 0,
     edges_dropped: int = 0,
     threes_dropped: int = 0;

node Room {
    has tag: int = 0;

    def drop {
        nodes_dropped += 1;
        if self.tag == 3 {
            threes_dropped += 1;
        }
    }
}

edge Door: Room --> Room {
    has w: int = 1;

    def drop {
        edges_dropped += 1;
    }
}

walker Tour {
    has seen: int = 0;

    can go with Room entry {
        self.seen += here.tag;
        visit [-->];
    }
}

walker Burn {
    has count: int = 0;

    can go with Room entry {
        self.count += 1;
        for n in [here-->][?:Room] {
            visit n;
        }
        for n in [here-->][?:Room] {
            here del --> n;
        }
    }
}

def reset {
    nodes_dropped = 0;
    edges_dropped = 0;
    threes_dropped = 0;
}

def read_nodes -> int {
    return nodes_dropped;
}

def read_edges -> int {
    return edges_dropped;
}

"""Nodes that were never connected are freed with their last reference."""
def loose(n: int) -> int {
    reset();
    for i in range(n) {
        r = Room(tag=i);
    }
    return nodes_dropped;
}

"""Connected nodes stay alive while the graph holds them."""
def held(n: int) -> int {
    reset();
    hub = Room(tag=0);
    for i in range(n) {
        hub ++> Room(tag=i + 1);
    }
    total = 0;
    for r in [hub-->][?:Room] {
        total += r.tag;
    }
    # Locals are released after their last use: read the count while `hub`
    # is still in use.
    seen = nodes_dropped;
    return seen * 1000 + total + hub.tag;
}

"""Disconnecting releases a target nothing else refers to, and its edge."""
def cut(n: int) -> int {
    reset();
    hub = Room(tag=0);
    for i in range(n) {
        hub +>:Door(w=i):+> Room(tag=i);
    }
    before = nodes_dropped + edges_dropped;
    for r in [hub->:Door:->][?:Room] {
        hub del --> r;
    }
    count = len([hub-->]);
    return before * 10000 + count * 1000 + nodes_dropped * 10 + edges_dropped;
}

"""A variable keeps a disconnected node alive."""
def kept_by_variable -> int {
    reset();
    hub = Room(tag=0);
    x = Room(tag=5);
    hub ++> x;
    hub del --> x;
    return x.tag * 10 + (1 if nodes_dropped <= 1 else 0);
}

"""Destroying a subgraph reclaims its nodes and edges."""
def destroy_tree(n: int) -> int {
    reset();
    hub = Room(tag=0);
    for i in range(n) {
        mid = Room(tag=i);
        hub +>:Door():+> mid;
        mid +>:Door():+> Room(tag=i);
    }
    for m in [hub->:Door:->][?:Room] {
        for leaf in [m->:Door:->][?:Room] {
            del leaf;
        }
        del m;
    }
    del hub;
    return nodes_dropped * 100 + edges_dropped;
}

"""A walk keeps the nodes it queued alive when an ability cuts them loose."""
def walk_cut -> int {
    reset();
    hub = Room(tag=1);
    hub ++> Room(tag=2);
    hub ++> Room(tag=3);
    w = hub spawn Burn();
    seen = nodes_dropped;
    return w.count * 100 + seen * 10 + hub.tag;
}

"""A walk over a chain visits each node once and frees nothing."""
def tour(n: int) -> int {
    reset();
    head = Room(tag=1);
    cur = head;
    for i in range(n) {
        nxt = Room(tag=1);
        cur ++> nxt;
        cur = nxt;
    }
    w = head spawn Tour();
    seen = nodes_dropped;
    return w.seen * 100 + seen * 10 + head.tag;
}

"""Edge objects read back from the graph stay valid while held."""
def edges_held -> int {
    reset();
    a = Room();
    b = Room();
    a +>:Door(w=7):+> b;
    total = 0;
    for e in [edge a->:Door:->] {
        total += e.w;
    }
    a del --> b;
    return total * 100 + edges_dropped;
}

"""A node address freed and reused starts with a clean graph entry."""
def reuse(n: int) -> int {
    reset();
    hub = Room(tag=0);
    ok = 0;
    for i in range(n) {
        x = Room(tag=i);
        hub ++> x;
        del x;
        y = Room(tag=i);
        hub ++> y;
        ok += len([hub-->]);
        hub del --> y;
    }
    return ok;
}

"""Destroy every node reachable from `start` in either direction."""
def destroy_all(start: Room) {
    seen: list[Room] = [start];
    i = 0;
    while i < len(seen) {
        n = seen[i];
        for m in [n-->][?:Room] {
            if m not in seen {
                seen.append(m);
            }
        }
        for m in [n<--][?:Room] {
            if m not in seen {
                seen.append(m);
            }
        }
        i += 1;
    }
    for n in seen {
        del n;
    }
}

def build_tree(n: int) -> Room {
    hub = Room(tag=0);
    for i in range(n) {
        mid = Room(tag=i);
        hub +>:Door():+> mid;
        mid +>:Door():+> Room(tag=i);
    }
    return hub;
}

"""A connected subgraph keeps itself alive until it is destroyed."""
def destroyed_tree(n: int) -> int {
    reset();
    hub = build_tree(n);
    hub = Room(tag=99);
    kept = nodes_dropped;
    return kept * 1000 + hub.tag;
}

"""Destroying a subgraph reached through its edges reclaims all of it."""
def teardown_tree(n: int) -> int {
    reset();
    hub = build_tree(n);
    destroy_all(hub);
    hub = Room(tag=99);
    return nodes_dropped * 1000 + edges_dropped;
}

"""Either end of an edge keeps the other reachable, as in Python."""
def backward_reach -> int {
    reset();
    leaf = Room(tag=7);
    Room(tag=5) ++> leaf;
    parents = [leaf<--][?:Room];
    return len(parents) * 100 + parents[0].tag * 10 + nodes_dropped;
}

def link_child(a: Room, b: Room) {
    b ++> [a-->][?:Room][0];
}

def cut_child(a: Room) {
    a del --> [a-->][?:Room][0];
}

def child_tag(a: Room) -> int {
    return [a-->][?:Room][0].tag;
}

"""A node two parents point to lives until both edges are gone."""
def shared_child -> int {
    reset();
    a = Room(tag=1);
    b = Room(tag=2);
    a ++> Room(tag=3);
    link_child(a, b);
    cut_child(a);
    after_a = threes_dropped;
    alive = child_tag(b);
    cut_child(b);
    after_b = threes_dropped;
    return alive * 100 + after_a * 10 + after_b + (a.tag + b.tag) * 0;
}

"""A program that destroys each world before building the next (a game
loading level after level) keeps only the current one."""
def levels(n: int) -> int {
    reset();
    world = Room(tag=0);
    for i in range(n) {
        destroy_all(world);
        world = Room(tag=i);
        for j in range(50) {
            area = Room(tag=j);
            world +>:Door():+> area;
            thing = Room(tag=j);
            world ++> thing;
            thing ++> area;
            area ++> thing;
        }
    }
    live = len([world-->]);
    return nodes_dropped * 1000 + live;
}

walker Peek {
    has n: int = 0;

    can see with Room entry {
        self.n += 1;
    }
}

walker Hop {
    can go with Room entry {
        if here.tag == 1 {
            visit first_child(here);
        }
    }
}

def first_child(a: Room) -> Room {
    return [a-->][?:Room][0];
}

def with_child -> Room {
    a = Room(tag=1);
    a ++> Room(tag=3);
    return a;
}

def cut_by_query(a: Room) {
    a del --> [a-->][?:Room][0];
}

def query_from_temp(a: Room) -> int {
    return len([first_child(a)-->]);
}

def spawn_on_temp(a: Room) {
    first_child(a) spawn Peek();
}

def visit_temp(a: Room) {
    a spawn Hop();
}

"""A graph operation handed a temporary node (a call result or an indexed
query) releases it, so the node is freed once it is cut loose. Each digit
is 1 when node 3 was freed after that operation."""
def temporaries_released -> int {
    got = 0;
    for step in range(5) {
        threes_dropped = 0;
        a = with_child();
        if step == 1 {
            query_from_temp(a);
        } elif step == 2 {
            spawn_on_temp(a);
        } elif step == 3 {
            visit_temp(a);
        } elif step == 4 {
            del first_child(a);
        }
        if step != 4 {
            cut_by_query(a);
        }
        got = got * 10 + threes_dropped + a.tag * 0;
    }
    return got;
}
