"""Fixture for abort-on-error tests: walkers that mutate then fail."""

node AbortItem {
    has name: str = "";
}

walker:protect CreateAndFail {
    can go with Root entry {
        here ++> AbortItem(name="ghost");
        raise Exception("intentional failure after mutation");
    }
}

walker:protect DeleteAndFail {
    can go with Root entry {
        for nbr in [-->] {
            del nbr;
        }
        raise Exception("intentional failure after delete");
    }
}

walker:protect CreateOk {
    has name: str = "kept";

    can go with Root entry {
        here ++> AbortItem(name=self.name);
        report {"ok": True};
    }
}

walker:protect CountItems {
    can go with Root entry {
        report {"count": len([-->])};
    }
}
