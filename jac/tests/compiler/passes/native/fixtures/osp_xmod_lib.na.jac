"""Native OSP library fixture (issue #6636, #4): archetypes imported by the
cross-module guardrail test. spawn / connect on these from another native
module must E5090 with help text naming this module as the reason, until
cross-module OSP materialization lands (#6146 Phases 3-4)."""

node Area { has tag: int = 0; }
edge In {}

walker Noop {
    has count: int = 0;
    can at_area with Area entry {
        self.count += 1;
    }
}
