node Person {
    has name: str,
        visited: bool = False;
}

edge FriendsWith {}

walker GreetFriends {
    can greet with Person entry {
        if not here.visited {
            here.visited = True;
            print(f"Hello, {here.name}!");

            visit [->:FriendsWith:->];
        }
    }
}

glob alice = root ++> Person(name="Alice"),
     bob = root ++> Person(name="Bob"),
     charlie = root ++> Person(name="Charlie");

with entry {
    alice +>:FriendsWith:+> bob +>:FriendsWith:+> charlie;
    alice +>:FriendsWith:+> charlie;

    alice[0] spawn GreetFriends();
}
