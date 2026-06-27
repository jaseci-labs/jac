import from collections.abc { Callable }
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor }

glob __all__ = ['HopSpec', 'QueryPlan'];


obj HopSpec {
    has edge_type: (str | None) = None,
        node_type: (str | None) = None,
        direction: int = 2;
}


obj QueryPlan {
    has root_id: (UUID | None) = None,
        chain: list[HopSpec] = [],
        field_predicates: dict = {},
        id_in: (set[UUID] | None) = None,
        slc: (slice | None) = None,
        node_type_final: (str | None) = None,
        post_filter: (Callable[[Anchor], bool] | None) = None;

    def is_trivial -> bool;
    def needs -> set[str];
    def repr -> str;
}
