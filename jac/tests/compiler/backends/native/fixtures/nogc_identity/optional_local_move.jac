obj Item {
    has v: int;

    def drop {
        print("drop", self.v);
    }
}

def exercise {
    first: own Item | None = Item(1);
    second: own Item | None = Item(2);
    first = second;
    third: own Item | None = first;
    print(third.v);
}

with entry {
    exercise();
    print("done");
}
