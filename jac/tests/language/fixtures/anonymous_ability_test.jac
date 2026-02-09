"""Test anonymous abilities with synthetic name generation."""

node TestNode {
    has name: str = "TestNode";

    can with entry {
        print("Node entry executed: " + self.name);
    }
}

walker TestWalker {
    can with Root entry {
        print("Walker root entry executed");
        n = TestNode();
        here ++> n;
        visit [-->];
    }

    can with TestNode entry {
        print("Walker visiting node");
    }

    can with Root exit {
        print("Walker root exit executed");
    }
}

with entry {
    root spawn TestWalker();
}
