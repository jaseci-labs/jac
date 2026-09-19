"""Domain model for the agent tool-surface fixture."""

node User {
    has name: str,
        age: int = 0;
}

node Post {
    has title: str,
        body: str = "";
}

edge Wrote: any --> any {}
