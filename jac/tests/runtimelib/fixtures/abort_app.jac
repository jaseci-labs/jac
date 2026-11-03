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

glob runs: list[int] = [];

def late_save(home: Root, name: str) {
    def late {
        home ++> AbortItem(name=name);
    }
    on_commit(late);
}

walker:protect LateWrite {
    has first: str = "first",
        late: str = "late";

    can go with Root entry {
        runs.append(1);
        here ++> AbortItem(name=self.first);
        late_save(here, self.late);
        report {"ok": True};
    }
}

def:protect late_note(late: str = "late") -> str {
    runs.append(1);
    root ++> AbortItem(name="first");
    late_save(root, late);
    return "noted";
}
