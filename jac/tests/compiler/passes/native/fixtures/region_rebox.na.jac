"""The `own` rebox (#7491 R4): a string copied out of a region owns its
bytes past the region's bulk free."""

glob drop_log: int = 0;

obj Named {
    has label: str = "";

    def drop {
        global drop_log;
        drop_log += 1;
    }
}

def out -> str {
    r: own Region = Region();
    s = "";
    in r {
        b = Named(label="hi");
        s = own b.label;
    }
    return s;
}
