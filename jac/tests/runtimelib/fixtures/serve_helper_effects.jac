"""Fixture: a walker that mutates the graph only through a helper def.

Used to verify the runtime endpoint-effect classifier follows calls into
helper functions instead of misclassifying the walker as a reader.
"""

node Item {
    has title: str;
    has tags: list = [];
}

# The graph write lives here, in a plain helper -- not in the walker body.
def _add_tag(it: Item, label: str) -> None {
    it.tags = it.tags + [label];
}

# Writer: its only mutation is delegated to the _add_tag helper.
walker tag_item {
    has label: str;

    can run with Root entry {
        items = [-->[?:Item]];
        for it in items {
            _add_tag(it, self.label);
        }
    }
}

# Reader: only reports, no mutation.
walker list_items {
    can run with Root entry {
        report [-->[?:Item]];
    }
}
