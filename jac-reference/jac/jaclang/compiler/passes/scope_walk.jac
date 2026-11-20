walker ScopeWalker {
    has seen: set[int] = set();

    can walk_scope with UniScopeNode entry;
}
