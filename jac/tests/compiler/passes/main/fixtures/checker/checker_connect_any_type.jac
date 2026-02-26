node MyNode {
    has val: int;
}

walker MyWalker {
    can do with MyNode entry {
        # List annotated as list (not list[MyNode]), so accessing list[0] gives any type
        nodes: list = [MyNode(0)];
        # Explicitly get the element which should be any type when list is untyped
        node_from_list = nodes[0];
        # Using any type in connection should not produce an error (for now)
        # TODO: In strict mode, this should be an error
        here ++> node_from_list;
    }
}
