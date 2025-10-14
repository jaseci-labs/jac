"""A Friend Finder Program"""

obj Person {
    has name: str;
    has friends: list[Person] = [];
    has visited: bool = False;

    def add_friend(friend: Person);
}


obj FriendFinder {
    has found_friends: list[str] = [];

    def find_friends(person: Person);
    def display_results;
}


with entry {
    # Create people
    alice = Person(name="Alice");
    bob = Person(name="Bob");
    charlie = Person(name="Charlie");
    diana = Person(name="Diana");

    # Build friend network
    alice.add_friend(bob);
    alice.add_friend(charlie);
    bob.add_friend(diana);
    charlie.add_friend(diana);

    # Find friends starting from Alice
    finder = FriendFinder();
    finder.find_friends(alice);
    finder.display_results();
}
