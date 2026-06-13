"""Native OSP library fixture (issue #6642 Blocker 2): the archetypes a consumer
module imports and then spawns / connects / edge-refs across the module boundary.
The `Counter` walker's ability itself navigates edges (`[here ->:Portal:->]`),
so its body -- compiled here with this module's tags -- must agree at runtime
with the consumer's connects (which use the consumer's tags). Deterministic
sorted tag numbering makes the two agree without recompiling this body."""

node Area { has tag: int = 0; }
edge Portal { has w: int = 0; }
edge In {}

walker Counter {
    has seen: int = 0, ports: int = 0;
    can at_area with Area entry {
        self.seen += here.tag;
        self.ports += len([here ->:Portal:->]);
        visit [here ->:Portal:->];
    }
}
