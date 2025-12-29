"""Spawn expressions (OSP): Walker instantiation with spawn operator."""

walker Counter {
    can count with `root entry;
}

node NumberNode {
    has value: int = 0;

    can process with Counter entry;
}

impl Counter.count{
    here ++> NumberNode(value=10);
    here ++> NumberNode(value=20);
    visit [-->];
}

impl NumberNode.process{
    print(f"Processing node with value: {self.value}");
}

# spawn operator: walker spawn starting_node
with entry {
    Counter() spawn root;

    # Also valid: starting_node spawn walker
    root spawn Counter();
}
