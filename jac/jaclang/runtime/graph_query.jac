import from uuid { UUID }
import from jaclang.runtime.archetype { Anchor, anchor_key }

glob QUERY_OPS: frozenset[str] = frozenset(
         {'==', '!=', '<', '<=', '>', '>=', 'in'}
     ),
     ORDERED_OPS: frozenset[str] = frozenset({'<', '<=', '>', '>='}),
     SCALARS: tuple[type, ...] = (str, int, float, bool, UUID);


obj QPred {
    has field: str | tuple[str, ...],
        op: str,
        value: any;

    def postinit -> None;
    def _check_composite -> None;
    def matches(subject: any) -> bool;
    def repr -> str;
}


obj QOrder {
    has field: str,
        desc: bool = False,
        on_edge: bool = False;
}


obj QHop {
    has dir: int,
        `edge: (type | None) = None,
        nd: (type | tuple[type, ...] | None) = None,
        epreds: list[QPred] = [],
        preds: list[QPred] = [],
        only: any = None;

    def add_node_constraint(node_type: (type | None)) -> None;
    def only_ids -> (set | None);
    def only_anchors -> list[Anchor];
    def only_keys -> (set | None);
    def repr -> str;
}


obj GraphQuery {
    has origin: list[any],
        hops: list[QHop] = [],
        edges_only: bool = False,
        from_visit: bool = False,
        slc: (slice | None) = None,
        order: list[QOrder] = [],
        limit: (int | None) = None,
        offset: int = 0,
        level: str = 'default';

    def init(
        origin: any,
        hops: (list[QHop] | None) = None,
        edges_only: bool = False,
        slc: (slice | None) = None,
        order: (list[QOrder] | None) = None,
        limit: (int | None) = None,
        offset: int = 0,
        level: str = 'default'
    ) -> None;

    def `visit -> GraphQuery;
    def narrow(
        nd: (type | None) = None, preds: (list[QPred] | None) = None, only: any = None
    ) -> GraphQuery;

    def repr -> str;
}
