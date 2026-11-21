import from .dynamic_edge_types_lib { Remote as RemoteAlias }

node Item {
    has value: int;
}

edge Role: Item --> Item {}
edge First(Role) {}
edge Second(Role) {}
edge Weighted(Role): Item --> Item {
    has weight: int = 7;
}

edge Heavy(Weighted) {}
edge Initialized(Role) {
    has weight: int = 0;

    def init(weight: int = 13) {
        self.weight = weight;
    }
}

edge Finished(Role) {
    has weight: int = 5;

    def postinit {
        self.weight += 4;
    }
}

edge Required(Role) {
    has weight: int;
}

edge Failing(Role) {
    def postinit {
        raise ValueError("edge initialization failed");
    }
}

obj NotAnEdge {}
obj EdgeChoice {
    has kind: type[Role];
}

glob selections: int = 0;

def select_edge -> type[Role] {
    selections += 1;
    return First;
}

def attach(a: Item, b: Item, kind: type[Role]) {
    a +>:(kind):+> b;
}

def count(a: Item, kind: type[Role]) -> int {
    return len([a->:kind:->]);
}

def clear(a: Item, kind: type[Role]) {
    del [edge a->:kind:->];
}

def probe(which: bool) -> int {
    a = Item(1);
    b = Item(2);
    c = Item(3);
    kind: type[Role] = First if which else Second;
    attach(a, b, kind);
    attach(a, c, Weighted);
    before = count(a, Role) * 100 + count(a, kind) * 10;
    clear(a, kind);
    return before + count(a, Role);
}

def constructors -> int {
    a = Item(1);
    b = Item(2);
    attach(a, b, Heavy);
    attach(a, b, Initialized);
    attach(a, b, Finished);
    weights = [edge a->:Weighted:->];
    initialized = [edge a->:Initialized:->];
    finished = [edge a->:Finished:->];
    return weights[0].weight * 10000 + initialized[0].weight * 100 + finished[0].weight;
}

def filtered(a: Item, kind: type[Weighted]) -> int {
    edges = [edge a->:kind:weight>=7:->];
    return edges[0].weight;
}

def disconnect(a: Item, b: Item, kind: type[Weighted]) {
    a del ->:kind:weight>=7:-> b;
}

def predicates -> int {
    a = Item(1);
    b = Item(2);
    a +>:Weighted(weight=3):+> b;
    attach(a, b, Heavy);
    before = filtered(a, Weighted);
    disconnect(a, b, Weighted);
    return before * 10 + count(a, Role);
}

def evaluated_once -> int {
    selections = 0;
    a = Item(1);
    b = Item(2);
    a +>:(select_edge()):+> b;
    return selections * 10 + count(a, First);
}

def invalid_constructor -> int {
    a = Item(1);
    b = Item(2);
    try {
        attach(a, b, Required);
    } except TypeError {
        return 10 + count(a, Role);
    }
    return -1;
}

def initializer_error -> int {
    a = Item(1);
    b = Item(2);
    try {
        attach(a, b, Failing);
    } except ValueError {
        return 10 + count(a, Role);
    }
    return -1;
}

def unbounded_attach(a: Item, b: Item, kind: type[Edge]) {
    a +>:(kind):+> b;
}

def unbounded_query(a: Item, kind: type) -> int {
    return len([a->:kind:->]);
}

def unbounded_types -> int {
    a = Item(1);
    b = Item(2);
    unbounded_attach(a, b, First);
    return unbounded_query(a, First);
}

def invalid_type -> int {
    a = Item(1);
    try {
        unbounded_query(a, NotAnEdge);
    } except TypeError {
        return 10 + count(a, Role);
    }
    return -1;
}

def imported_types -> int {
    a = Item(1);
    b = Item(2);
    unbounded_attach(a, b, RemoteAlias);
    edges = [edge a->:RemoteAlias:->];
    return len(edges) * 100 + unbounded_query(a, RemoteAlias) * 10 + edges[0].weight;
}

def stored_types -> int {
    a = Item(1);
    b = Item(2);
    choice = EdgeChoice(First);
    a +>:(choice.kind):+> b;
    kinds: dict[str, type[Role]] = {"second": Second};
    attach(a, b, kinds["second"]);
    return count(a, First) * 10 + count(a, Second);
}

def endpoint_value(a: Item, kind: type[Role]) -> int {
    targets = [a->:kind:->];
    return targets[0].value;
}

def typed_endpoints -> int {
    a = Item(1);
    b = Item(42);
    attach(a, b, First);
    return endpoint_value(a, First);
}

def typed_collections -> int {
    a = Item(1);
    b = Item(7);
    c = Item(11);
    attach(a, b, First);
    kind: type[Role] = First;
    values = [c, *[a->:kind:->]];
    total = 0;
    for item in [a->:kind:->] {
        if isinstance(item, Item) {
            total += item.value;
        }
    }
    return total + values[0].value + values[1].value;
}
