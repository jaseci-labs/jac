"""Elements the `social` entry re-imports instead of declaring itself."""

walker:pub Relay {
    has name: str;

    can go with Root entry {
        report self.name;
    }
}

walker Sweep {
    can go with Root entry {
        report 0;
    }
}

def:pub relay(name: str) -> str {
    return name;
}
