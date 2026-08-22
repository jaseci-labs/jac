import logging;
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor }
import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }
import from jaclang.runtimelib.session { Session }
import from jaclang.runtimelib.sqlcompile { compile_query }

glob logger = logging.getLogger(__name__),
     __all__ = ['resolve_query', 'resolve_query_edges', 'resolve_query_prefix'];


def _origin_anchors(q: GraphQuery) -> list[Anchor];


def _sql_pairs(
    mem: Session, origin_ids: list[UUID], q: GraphQuery, upto: int
) -> list[tuple[(UUID | None), (UUID | None)]];


def _edge_pair_for(e: EdgeAnchor, cur: Anchor, hop: QHop) -> (Anchor | None);


def _walk_memory(
    origins: list[Anchor], q: GraphQuery, upto: int
) -> list[tuple[Anchor, (EdgeAnchor | None)]];


def _hop_matches_node(anchor: Anchor, hop: QHop) -> bool;


def resolve_query_prefix(mem: Session, q: GraphQuery, upto: int) -> list[UUID];


def _acl_gated -> bool;


def _acl_read_ok(anchor: Anchor) -> bool;


def resolve_query(mem: Session, q: GraphQuery) -> list[Anchor];


def resolve_query_edges(mem: Session, q: GraphQuery) -> list[Anchor];
