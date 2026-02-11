node Person {
    has name: str;

    can announce with FriendFinder entry {
        print(f"{visitor} is checking me out");
    }
}

edge Friend {}
edge Family {
    can announce with FriendFinder entry {
        print(f"{visitor} is traveling to family member");
    }
}

# Susan has a friend connection to John's
glob p1 = Person(name="John"),
     p2 = Person(name="Susan"),
     p3 = Person(name="Mike"),
     p4 = Person(name="Alice");

with entry {
    root ++> p1;
    p1 +>: Friend :+> p2;
    p2 +>: Family :+> [p1, p3];
    p2 +>: Friend :+> p3;
}

# This is also a class
walker FriendFinder {
    has started: bool = False;

    # this is a special method (ability)
    can report_friend with Person entry {
        if self.started {
            print(f"{here.name} is a friend of friend, or family");
        } else {
            self.started = True;
            visit [-->];
        }
        visit [edge ->:Family:->];
    }

    can move_to_person with Root entry {
        visit [-->];
    }
}

glob result = FriendFinder() spawn root;

with entry {
    print(result);
}
