walker Visitor {
    can self_destruct with entry {
        print("get's here");
        disengage;
        print("but not here");
    }
}

with entry {
    root spawn Visitor();
}
