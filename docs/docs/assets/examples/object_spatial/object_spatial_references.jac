walker Creator {
    can create with Root entry;
}

node node_a {
    has val: int;

    can make_something with Creator entry;
}

edge connector {
    has value: int = 10;
}

impl Creator.create{
    # Build a chain of node_a's hanging off the entry root: each step
    # creates a new node, links from `end`, then advances `end` to it.
    head = node_a(val=0);
    here ++> head;
    end = head;
    for i = 1 to i < 3 by i += 1 {
        next = node_a(val=i);
        end ++> next;
        end = next;
    }
    # Typed-edge fan-outs from the chain's tail and from root.
    fwd_tail = node_a(val=i + 10);
    end +>: connector(value=i) :+> fwd_tail;
    bwd_tail = node_a(val=i + 10);
    root <+: connector(value=i) :<+ bwd_tail;
    visit [-->];
}

impl node_a.make_something{
    i = 0;
    while i < 5 {
        print(f"welcome to {self}");
        i += 1;
    }
}

with entry {
    root spawn Creator();
}
