impl Person.add_friend(friend: Person) {
    if friend not in self.friends {
        self.friends.append(friend);
    }
}


impl FriendFinder.find_friends(person: Person) {
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


impl FriendFinder.display_results {
    if self.found_friends {
        print("Found friends:");
        for name in self.found_friends {
            print(f"  - {name}");
        }
    } else {
        print("No friends found.");
    }
}
