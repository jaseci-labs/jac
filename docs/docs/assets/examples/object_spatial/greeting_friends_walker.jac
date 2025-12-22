node Person {
    has name: str,
        visited: bool = False;
}

edge FriendsWith {}

# This walker will greet every person it meets
walker GreetFriends {
    can greet with Person entry {
        if not here.visited {
            here.visited = True;
            print(f"Hello, {here.name}!");
            # Now, tell the walker to go to all connected friends
            visit [->:FriendsWith:->];
        }
    }
}

# Create friend network
glob alice = root ++> Person(name="Alice"),
     bob = root ++> Person(name="Bob"),
     charlie = root ++> Person(name="Charlie");

# Connect friends
with entry {
    alice +>: FriendsWith :+> bob +>: FriendsWith :+> charlie;
    alice +>: FriendsWith :+> charlie;  # Alice also friends with Charlie

    # Start the walker on the 'alice' node to greet everyone
    alice[0] spawn GreetFriends();
}
# To keep track of who we've greeted
