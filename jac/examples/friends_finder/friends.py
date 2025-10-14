"""A Friend Finder Program"""

class Person:
    def __init__(self, name):
        self.name = name
        self.friends = []
        self.visited = False

    def add_friend(self, friend):
        if friend not in self.friends:
            self.friends.append(friend)


class FriendFinder:
    def __init__(self):
        self.found_friends = []

    def find_friends(self, person):
        """Find all friends and friends of friends"""
        if person.visited:
            return

        person.visited = True

        for friend in person.friends:
            if not friend.visited:
                self.found_friends.append(friend.name)
                self.find_friends(friend)

    def display_results(self):
        if self.found_friends:
            print("Found friends:")
            for name in self.found_friends:
                print(f"  - {name}")
        else:
            print("No friends found.")


if __name__ == "__main__":
    # Create people
    alice = Person("Alice")
    bob = Person("Bob")
    charlie = Person("Charlie")
    diana = Person("Diana")

    # Build friend network
    alice.add_friend(bob)
    alice.add_friend(charlie)
    bob.add_friend(diana)
    charlie.add_friend(diana)

    # Find friends starting from Alice
    finder = FriendFinder()
    finder.find_friends(alice)
    finder.display_results()
