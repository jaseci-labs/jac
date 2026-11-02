walker TreeWalker {}

node Tree {
    has label: str = "";

    can walk_kids with TreeWalker entry {
        visit:0: [self->:Kid:->];
    }
}

edge Kid: Tree --> Tree {}
