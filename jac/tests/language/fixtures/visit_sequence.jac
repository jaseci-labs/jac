node Node {
    has val: str;

    can entry1 with entry {
        print(f"{self.val}-2");
    }

    can entry2 with Walker entry {
        print(f"{self.val}-3");
    }

    can exit1 with Walker exit {
        print(f"{self.val}-4");
    }

    can exit2 with exit {
        print(f"{self.val}-5");
    }
}

walker Walker {
    can entry1 with entry {
        print("walker entry");
    }

    can entry2 with `root entry {
        print("walker enter to root");
        visit [-->];
    }

    can entry3 with Node entry {
        print(f"{here.val}-1");
    }

    can exit1 with Node exit {
        print(f"{here.val}-6");
    }

    can exit2 with exit {
        print("walker exit");
    }
}

with entry {
    root ++> Node(val="a");
    root ++> Node(val="b");
    root ++> Node(val="c");

    Walker() spawn root;
}
