"""A Friend Finder Program"""

obj Person {
    def init(self: Person, name: str) {
        self.name = name;
        self.friends = [];
        self.visited = False;
    }

    def add_friend(self: Person, friend: Person) {
        if friend not in self.friends {
            self.friends.append(friend);
        }
    }
}


obj FriendFinder {
    def init(self: FriendFinder) {
        self.found_friends = [];
    }

    def find_friends(self: FriendFinder, person: Person) {
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

    def display_results(self: FriendFinder) {
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
    alice = Person("Alice");
    bob = Person("Bob");
    charlie = Person("Charlie");
    diana = Person("Diana");

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
