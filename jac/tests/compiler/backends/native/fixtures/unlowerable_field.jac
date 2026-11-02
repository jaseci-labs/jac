# Fixture for the no-rescue diagnostic gate (#7871 F). A field whose declared
# type has no native lowering must be refused loudly, naming the field or its
# type, rather than erased to a slot the native side never wrote.

obj Holder {
    has view: memoryview,
        tag: int = 7;
}

def read_view(h: Holder) -> int {
    v = h.view;
    return 1;
}

def read_tag(h: Holder) -> int {
    return h.tag;
}

def holder_tag -> int {
    return 7;
}

glob _x: int = 1;
