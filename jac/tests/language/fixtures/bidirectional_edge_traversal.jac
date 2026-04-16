node MyNode {
    has val: int;
}

edge Friend;
edge Follows;

walker travel {
    can visit_friends with MyNode exit {
        for fnd in [->:Friend:->] {
            print("Friend found:", fnd.val);
        }
    }
}

walker travel_in {
    can visit_friends_in with MyNode exit {
        for fnd in [<-:Friend:<-] {
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

walker travel_follows_out {
    can visit_out with MyNode exit {
        for fnd in [->:Follows:->] {
            print("Follower found:", fnd.val);
        }
    }
}

walker travel_follows_in {
    can visit_in with MyNode exit {
        for fnd in [<-:Follows:<-] {
            print("Follower found:", fnd.val);
        }
    }
}

glob a = MyNode(val=1),
     b = MyNode(val=2);

# Create bidirectional edge
with entry {
    a <+: Friend :+> b;

    # Test from a to b
    print("From a:");
    a spawn travel();

    # Test from b to a (the fix!)
    print("From b:");
    b spawn travel();
}

# Generic undirected edge
glob c = MyNode(val=3),
     d = MyNode(val=4);

with entry {
    c <++> d;

    print("Generic from c:");
    c spawn travel_generic();

    print("Generic from d:");
    d spawn travel_generic();

    # IN-direction walker must also traverse undirected edges bidirectionally
    print("Reverse from a:");
    a spawn travel_in();

    print("Reverse from b:");
    b spawn travel_in();
}

# Directed edge: non-regression — direction filter must still exclude reverse
glob e = MyNode(val=5),
     f = MyNode(val=6);

with entry {
    e +>: Follows :+> f;

    print("Forward from e:");
    e spawn travel_follows_out();
    print("Forward from f:");
    f spawn travel_follows_out();

    print("Backward from f:");
    f spawn travel_follows_in();
    print("Backward from e:");
    e spawn travel_follows_in();

    print("Done.");
}
