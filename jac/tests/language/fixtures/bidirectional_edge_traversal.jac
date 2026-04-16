node MyNode {
    has val: int;
}

edge Friend;

walker travel {
    can visit_friends with MyNode exit {
        for fnd in [->:Friend:->] {
            print("Friend found:", fnd.val);
        }
    }
}

walker travel_generic {
    can visit_generic with MyNode exit {
        for neighbor in [-->] {
            print("Neighbor found:", neighbor.val);
        }
    }
}

with entry {
    a = MyNode(val=1);
    b = MyNode(val=2);

    # Create bidirectional edge
    a <+:Friend:+> b;

    # Test from a to b
    print("From a:");
    a spawn travel();

    # Test from b to a (the fix!)
    print("From b:");
    b spawn travel();

    # Generic undirected edge
    c = MyNode(val=3);
    d = MyNode(val=4);
    c <++> d;

    print("Generic from c:");
    c spawn travel_generic();

    print("Generic from d:");
    d spawn travel_generic();
}
