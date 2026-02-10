"""Test skip statement parsing."""

walker Searcher {
    has found: bool = False;

    can search with Root entry {
        if self.found {
            skip;
        }
        visit [-->];
    }
}
