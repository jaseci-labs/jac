"""An edge without an endpoint clause widens to `any` silently; say it out loud."""
node Spot {
    has k: int = 0;
}

edge Bare: any --> any {}
edge Widened: any --> any {}
edge AnyNode: Node --> Node {}
edge Precise: Spot --> Spot {}
