walker ScopeWalker {
    has seen: set[int] = set();

    can walk_scope with UniScopeNode entry {
        if id(here) in self.seen {
            osp_skip_rest();
            return;
        }
        self.seen.add(id(here));
        visit:0: [here->:ScopeChild:->];
    }
}
