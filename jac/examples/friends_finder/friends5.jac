"""A Friend Finder Program - Cloud Ready"""

node Person {
    has name: str;
    has visited: bool = False;

    can greet with FriendFinder entry {
        if not self.visited {
            self.visited = True;
            print(f"Found friend: {self.name}");
            visitor.found_friends.append(self.name);
            visit [-->];
        }
    }
}

edge Friends {}


walker FriendFinder {
    has starting_person: str;
    has found_friends: list[str] = [];

    can find_network with `root entry {
        # Check if network exists, if not build it first
        existing_people = [-->](`?Person);

        if not existing_people {
            print("Network not found. Please build it first.");
            return;
        }

        # Find the starting person
        target = [-->](`?Person)(?name == self.starting_person);

        if target {
            print(f"Starting friend search from {self.starting_person}...");
            visit target;
            print(f"\nTotal friends found: {len(self.found_friends)}");
        } else {
            print(f"Person {self.starting_person} not found.");
        }
    }
}


walker BuildNetwork {
    has people: dict[str, str];
    has connections: list[tuple[str, str]];

    can build with `root entry {
        # Create person nodes
        person_nodes = {};
        for id, name in self.people.items() {
            person_nodes[id] = root ++> Person(name=name);
        }

        # Create friend connections
        for person1_id, person2_id in self.connections {
            person_nodes[person1_id] +>:Friends:+> person_nodes[person2_id];
        }

        print("Network built successfully!");
    }
}


with entry {
    # Build the network first
    BuildNetwork(
        people={"alice": "Alice", "bob": "Bob", "charlie": "Charlie", "diana": "Diana"},
        connections=[("alice", "bob"), ("alice", "charlie"), ("bob", "diana"), ("charlie", "diana")]
    ) spawn root;

    # Find friends starting from Alice
    FriendFinder(starting_person="Alice") spawn root;
}
