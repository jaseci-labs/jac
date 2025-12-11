# Define a simple node type called `Item`
node Item {
    has value: int = 0;
}

# Define an edge type called `Link`
edge Link {}

# Define the `bar` walker
walker bar_walk {
    has count: int = 0;

    # Start walking from the root node or an Item node
    can start with `root | Item entry {
        here ++> Item();
        if self.count < 5 {
            visit [-->];
        } else {
            "Created 5 items." |> print;
            disengage;
        }
    }

    # Walk over Item nodes and update their values
    can walk with Item entry {
        here.value = self.count;
        f"Item value: {here.value}" |> print;
        self.count += 1;
        visit [-->] else {
            "Finished walking over all items." |> print;
            disengage;
        }
    }
}
