"""A root class nobody in its own module derives from: lowered flat."""
obj FlatSource {
    has seen: int = 0;

    def trace(x: int) -> int {
        return -1;
    }

    def spot(x: int) -> int {
        self.seen += 1;
        return self.trace(x);
    }

    def name -> str {
        return "flat";
    }
}

"""The supported shape: an abstract method reserves dispatch for
implementations in other modules."""
obj OpenSource {
    def trace(x: int) -> int abst;
    def spot(x: int) -> int {
        return self.trace(x);
    }
}
