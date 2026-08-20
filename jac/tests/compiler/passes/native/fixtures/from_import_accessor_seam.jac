"""Fixture: a `from`-import violation inside a property accessor.

A `{ getter; }` body is a callable the native lane lowers as a method, keyed by
the accessor Ability and named `<Archetype>.<field>.__get__` in the demotion
coverage. A capability violation written there therefore has an owner to demote
to, exactly as a plain method does, and the archetype's ordinary methods stay
native around it.
"""

obj Box {
    has head: int = 7;
    has tagged: int { getter; }

    def plain -> int {
        return self.head + 1;
    }
}


impl Box.tagged.getter -> int {
    import from collections { OrderedDict }
    return self.head + len(OrderedDict());
}


def run -> int {
    return Box().plain();
}
