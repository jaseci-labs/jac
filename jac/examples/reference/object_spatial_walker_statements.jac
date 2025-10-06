# Object spatial walker statements - Graph traversal and spatial operations

walker Visitor {
    can self_destruct with `root entry {
        print("get's here");
        disengage;
        print("but not here");
    }
}

with entry {
    root spawn Visitor();
}
