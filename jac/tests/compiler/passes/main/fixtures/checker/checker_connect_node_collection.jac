node Todo {
    has title: str,
        done: bool;
}

node Item {
    has name: str;
}

with entry {
    # Connecting root to a list of nodes should not produce an error
    root ++> [
        Todo(title="task1", done=False),
        Todo(title="task2", done=False),
        Todo(title="task3", done=False)
    ];

    # Connecting to a tuple of nodes should also work
    root ++> (Item(name="item1"), Item(name="item2"));

    # Single node connection should still work
    root ++> Todo(title="single", done=True);
}
