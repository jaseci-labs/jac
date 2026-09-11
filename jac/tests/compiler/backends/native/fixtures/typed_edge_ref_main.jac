import from .typed_edge_ref_base { Graph, Value, Token, Child }

node First(Value) {}
node Second(Value) {}
node Container(Graph) {
    def choices -> list[Graph] {
        return [
            child
            for child in [self->:Child:->]
            if isinstance(child, (First, Second))
        ];
    }
}

def comprehension -> int {
    box = Container();
    box +>:Child:+> First(value=11);
    box +>:Child:+> Token();
    box +>:Child:+> Second(value=22);
    return len(box.choices());
}

def iteration -> int {
    box = Container();
    box +>:Child:+> First(value=11);
    box +>:Child:+> Token();
    box +>:Child:+> Second(value=22);
    total = 0;
    for child in [box->:Child:->] {
        if isinstance(child, Value) {
            total += child.value;
        }
    }
    return total;
}
