"""Typed graph references retain object identity through an erased union."""

node Base {}
glob drops: int = 0;
node Child(Base) {
    has value: int = 73;

    def drop {
        drops += 1;
    }
}

edge Link: Base --> Child {}
edge UntypedLink {}

def erased_references -> list[any] {
    source = Base();
    destination = Child();
    source +>:UntypedLink:+> destination;
    return [source->:UntypedLink:->];
}

def erased_identity -> bool {
    values = erased_references();
    value = values[0];
    valid = len(values) == 1 and isinstance(value, Child);
    values.clear();
    return valid and isinstance(value, Child);
}

def filtered_identity -> bool {
    source = Base();
    destination = Child();
    source +>:UntypedLink:+> destination;
    values = [source->:UntypedLink:->][?:Child][?:Child];
    stored = erased_references();
    filtered = stored[?:Child];
    return len(values) == 1
        and values[0] is destination
        and len(filtered) == 1
        and filtered[0].value == 73;
}

def first(source: Base) -> Base | list[Base] | None {
    found = [source->:Link:->];
    if found {
        return found[0];
    }
    return None;
}

def probe -> bool {
    source = Base();
    destination = Child();
    source +>:Link:+> destination;
    value = first(source);
    return isinstance(value, Child) and value is destination;
}

def references -> list[Child] {
    source = Base();
    destination = Child();
    source +>:Link:+> destination;
    return [source->:Link:->];
}

def retained -> bool {
    drops = 0;
    values = references();
    valid = drops == 0 and len(values) == 1 and values[0].value == 73;
    values.clear();
    return valid and len(values) == 0;
}

def regional_references -> bool {
    region: own Region = Region();
    in region {
        valid = retained();
    }
    return valid;
}

def read_drops -> int {
    return drops;
}
