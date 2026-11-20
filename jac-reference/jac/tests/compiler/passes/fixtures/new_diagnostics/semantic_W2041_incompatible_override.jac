"""Fixture for W2041: Method overrides parent but changes signature incompatibly."""

obj Base {
    def process(self: Base, data: str) -> int {
        return len(data);
    }
}

obj GoodChild(Base) {
    def process(self: GoodChild, data: str) -> int {  # <-- Ok: same signature
        return len(data) * 2;
    }
}

obj BadChild(Base) {
    def process(self: BadChild, data: int) -> str {  # <-- Warning W2041: incompatible
        return str(data);
    }
}
