obj Resource {
    has value: int;

    def drop {
        print(f"drop {self.value}");
    }
}

def branch(flag: bool) {
    first: own Resource = Resource(value=1);
    if flag {
        second: own Resource = Resource(value=2);
        print(second.value);
    }
    print(first.value);
}

with entry {
    branch(False);
    branch(True);
}
