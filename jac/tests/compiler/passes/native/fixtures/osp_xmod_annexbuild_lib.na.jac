"""Regression fixture (OSP library half, issue: impl-annex OSP usage). Declares
the graph archetypes and the walker. Imported by both the builder module (which
wires the graph from an IMPL ANNEX) and the entry module (which spawns)."""

node Hub {}
node Area { has tag: int = 0; }

walker Pass {
    has seen: int = 0;

    can start with Hub entry {
        visit [here -->[?:Area]];
    }

    can at_area with Area entry {
        self.seen += here.tag;
    }
}
