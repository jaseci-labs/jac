"""Fixture for testing in-place mutation detection via hash-based dirty checking."""

node Item {
    has id: int,
        tags: list[str] = [],
        metadata: dict[str, str] = {},
        scores: set[int] = set(),
        completed: bool = False;
}

walker:pub CreateItem {
    has id: int;

    can create with Root entry {
        new_item = here ++> Item(id=self.id);
        report new_item;
    }
}

walker:pub GetItems {
    can read with Root entry {
        report [-->];
    }
}

walker:pub AppendTag {
    has id: int,
        tag: str;

    can find with Root entry {
        for item in [-->] {
            if (self.id == item.id) {
                visit item;
            }
        }
    }

    can mutate with Item entry {
        here.tags.append(self.tag);
        report here;
    }
}

walker:pub SetMeta {
    has id: int,
        key: str,
        value: str;

    can find with Root entry {
        for item in [-->] {
            if (self.id == item.id) {
                visit item;
            }
        }
    }

    can mutate with Item entry {
        here.metadata[self.key] = self.value;
        report here;
    }
}

walker:pub SetCompleted {
    has id: int;

    can find with Root entry {
        for item in [-->] {
            if (self.id == item.id) {
                visit item;
            }
        }
    }

    can mutate with Item entry {
        here.completed = True;
        report here;
    }
}
