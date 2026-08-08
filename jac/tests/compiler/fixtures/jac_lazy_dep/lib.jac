"""Dependency module for lazy .jac JIR tests."""

class Alpha {
    has value: int = 1;

    can double -> int {
        return self.value * 2;
    }
}

class Beta {
    has label: str = "beta";

    can greet -> str {
        return "hello " + self.label;
    }
}

glob counter: int = 0;

def bump -> int {
    global counter;
    counter += 1;
    return counter;
}
