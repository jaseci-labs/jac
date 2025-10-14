"""A Friend Finder Program using Object Spatial Programming"""

node Person {
    has name: str;
    has visited: bool = False;

    can greet with FriendFinder entry {
        if not self.visited {
            self.visited = True;
            print(f"Found friend: {self.name}");
            visitor.found_friends.append(self.name);

            # Visit all connected friends
            visit [-->];
        }
    }
}

edge Friends {}


walker FriendFinder {
    has found_friends: list[str] = [];

    can find_network with `root entry {
        print("Starting friend search...");
        # Move to the first person and let the graph walk itself
        visit [-->];

        # Display results when traversal completes
        if self.found_friends {
            print(f"\nTotal friends found: {len(self.found_friends)}");
        } else {
            print("\nNo friends found.");
        }
    }
}


with entry {
    # Create people as nodes connected to root
    alice = root ++> Person(name="Alice");
    bob = root ++> Person(name="Bob");
    charlie = root ++> Person(name="Charlie");
    diana = root ++> Person(name="Diana");

    # Build friend network using edges
    alice +>:Friends:+> bob;
    alice +>:Friends:+> charlie;
    bob +>:Friends:+> diana;
    charlie +>:Friends:+> diana;

    # Spawn walker starting from Alice
    FriendFinder() spawn alice[0];
}
