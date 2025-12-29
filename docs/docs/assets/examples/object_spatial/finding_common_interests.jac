node Person {
    has name: str,
        age: int,
        interests: list[str] = [];
}

edge FriendsWith {
    has since: str,
        closeness: int;
}

walker FindCommonInterests {
    has target_person: Person,
        common_interests: list[str] = [];

    can find_common with Person entry {
        if here == self.target_person {
            return;  # Skip self

        }

        # Find shared interests
        shared = [];
        for interest in here.interests {
            if interest in self.target_person.interests {
                shared.append(interest);
            }
        }

        if shared {
            self.common_interests.extend(shared);
            print(
                f"{here.name} and {self.target_person.name} both like: {', '.join(
                    shared
                )}"
            );
        }
    }
}

# Create friend network
glob alice = root ++> Person(
         name="Alice", age=25, interests=["coding", "music", "hiking"]
     ),
     bob = root ++> Person(
         name="Bob", age=27, interests=["music", "sports", "cooking"]
     ),
     charlie = root ++> Person(
         name="Charlie", age=24, interests=["coding", "gaming", "music"]
     );

# Create friendships with metadata
with entry {
    alice +>: FriendsWith(since="2020-01-15", closeness=8) :+> bob;
    alice +>: FriendsWith(since="2021-06-10", closeness=9) :+> charlie;
    bob +>: FriendsWith(since="2020-12-03", closeness=7) :+> charlie;

    print("=== Friend Network Analysis ===");
}

# 1. Find all nodes connected to Alice by a FriendsWith edge
glob alice_friends = [alice[
         0
     ]->:FriendsWith:->(`?Person)];

with entry {
    print(f"Alice's friends: {[f.name for f in alice_friends]}");
}

# 2. Create an instance of our walker, telling it to compare against Alice
glob finder = FindCommonInterests(
         target_person=alice[0]
     );

# 3. Send the walker to visit each of Alice's friends
with entry {
    for friend in alice_friends {
        friend spawn finder;
    }
}

# Find close friendships (closeness >= 8)
glob close_friendships = [root-->->:FriendsWith:closeness>=8:->];

with entry {
    print(f"Close friendships ({len(close_friendships)} found):");
}
# 1-10 scale
