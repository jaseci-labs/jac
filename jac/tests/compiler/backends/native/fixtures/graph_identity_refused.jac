"""Bound endpoints native lowering refuses: only a node or a list of nodes
is read as the wanted far ends. A tuple or a set of nodes is laid out
differently, so its function stays off the native lane."""

node Room {
    has tag: int = 0;
}

edge Door: Room --> Room {
    has w: int = 1;
}

def list_end -> int {
    hub = Room(tag=0);
    a = Room(tag=1);
    b = Room(tag=2);
    hub +>:Door():+> a;
    hub +>:Door():+> b;
    ends: list[Room] = [a, b];
    return len([hub->:Door:->ends]);
}

def tuple_end -> int {
    hub = Room(tag=0);
    a = Room(tag=1);
    b = Room(tag=2);
    hub +>:Door():+> a;
    hub +>:Door():+> b;
    ends: tuple[Room, Room] = (a, b);
    return len([hub->:Door:->ends]);
}

def set_end -> int {
    hub = Room(tag=0);
    a = Room(tag=1);
    b = Room(tag=2);
    hub +>:Door():+> a;
    hub +>:Door():+> b;
    ends: set[Room] = {a, b};
    return len([hub->:Door:->ends]);
}
