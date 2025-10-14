"""A Friend Finder Program"""

obj Person {
    has name: str;
    has friends: list[Person] = [];
    has visited: bool = False;

    def add_friend(friend: Person) {
        if friend not in self.friends {
            self.friends.append(friend);
        }
    }
}


obj FriendFinder {
    has found_friends: list[str] = [];

    def find_friends(person: Person) {
        """Find all friends and friends of friends"""
        if person.visited {
            return;
        }

        person.visited = True;

        for friend in person.friends {
            if not friend.visited {
                self.found_friends.append(friend.name);
                self.find_friends(friend);
            }
        }
    }

    def display_results {
        if self.found_friends {
            print("Found friends:");
            for name in self.found_friends {
                print(f"  - {name}");
            }
        } else {
            print("No friends found.");
        }
    }
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
