"""A base with a `drop` hook, held by own references typed as the base.

Nothing here subclasses `Resource`; `release_all` and `Holder` still drop
whatever subclass instance an importer stored in them.
"""

obj Payload {
    has tag: str = "";

    def drop {
        print("drop payload " + self.tag);
    }
}

obj Resource {
    has name: str = "";

    def drop {
        print("drop resource " + self.name);
    }
    def size -> int {
        return 0;
    }
}

obj Holder {
    has slot: own Resource = Resource(name="empty");
}

def release_all(items: own list[Resource]) -> int {
    total = 0;
    for r in items {
        total += r.size();
    }
    return total;
}
