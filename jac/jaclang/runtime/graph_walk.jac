glob __all__ = [
         'access_gated',
         'acl_read_ok',
         'bounded',
         'edge_pair_for',
         'hop_matches_node',
         'needs_store',
         'origin_anchors',
         'pred_subject',
         'unique_anchors',
         'walk',
         'walk_edges',
         'walk_nodes'
     ];


def access_gated -> bool;


def acl_read_ok(anchor: Anchor) -> bool;


def has_persistent_origin(origins: list[Anchor]) -> bool;


def needs_store(mem: any, origins: list[Anchor]) -> bool;


def origin_anchors(q: GraphQuery) -> list[Anchor];


def pred_subject(arch: any, p: QPred) -> any;


def hop_matches_node(anchor: Anchor, hop: QHop) -> bool;


def edge_pair_for(e: EdgeAnchor, cur: Anchor, hop: QHop) -> (Anchor | None);


def _walk_light(
    cur: NodeAnchor,
    hop: QHop,
    outgoing: bool,
    want_edges: bool,
    gated: bool,
    seen: set,
    nxt: list[tuple[Anchor, (EdgeAnchor | None)]]
) -> None;


def walk(
    origins: list[Anchor], q: GraphQuery, upto: int, gated: bool
) -> list[tuple[Anchor, (EdgeAnchor | None)]];


def unique_anchors(pairs: list[tuple[Anchor, (EdgeAnchor | None)]]) -> list[Anchor];


def bounded(out: list[Anchor], q: GraphQuery) -> list[Anchor];


def walk_nodes(origins: list[Anchor], q: GraphQuery, gated: bool) -> list[Anchor];


def walk_edges(origins: list[Anchor], q: GraphQuery, gated: bool) -> list[Anchor];
