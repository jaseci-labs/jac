node Parent {
    has visited: int = 0;

    can touch with Base entry {
        self.visited += 1;
    }
}

node Item(Parent) {}

walker Base {
    has count: int = 0;

    can first with Item entry {
        self.count = self.count * 10 + 1;
    }

    def run(item: Item) -> int {
        item spawn self;
        return self.count;
    }
}
