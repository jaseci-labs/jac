"""Domain model for the agent tool-surface fixture."""

node User {
    has name: str;
    has age: int = 0;
}

node Post {
    has title: str;
    has body: str = "";
}

edge Wrote {}
