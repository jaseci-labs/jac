import logging;
import from uuid { UUID }
import from jaclang.runtime.archetype { Anchor, EdgeAnchor, anchor_key }
import from jaclang.runtime.graph_query { GraphQuery, QPred }
import from jaclang.runtime.graph_walk {
    access_gated,
    acl_read_ok,
    needs_store,
    origin_anchors,
    pred_subject,
    walk,
    walk_edges,
    walk_nodes
}
import from jaclang.server.session { Session }
import from jaclang.data.sqlcompile { compile_query }

glob logger = logging.getLogger(__name__),
     __all__ = [
         'resolve_query',
         'resolve_query_edges',
         'resolve_query_prefix',
         'resolve_query_count',
         'resolve_query_exists',
         'LazyRefs'
     ];


def _sql_pairs(
    mem: Session, origin_ids: list[UUID], q: GraphQuery, upto: int
) -> tuple[list[tuple[(UUID | None), (UUID | None)]], list[QPred]];


def resolve_query_prefix(mem: Session, q: GraphQuery, upto: int) -> list[UUID];


def resolve_query(mem: Session, q: GraphQuery) -> list[Anchor];


def resolve_query_edges(mem: Session, q: GraphQuery) -> list[Anchor];


def resolve_query_count(mem: Session, q: GraphQuery) -> int;


def resolve_query_exists(mem: Session, q: GraphQuery) -> bool;


class LazyRefs(list) {
    def init(self: LazyRefs, resolve: any, query: GraphQuery) -> None;
    def _realize(self: LazyRefs) -> None;
    def _bounded(self: LazyRefs, limit: (int | None), offset: int) -> list[any];
    def _count(self: LazyRefs) -> int;
    def _mem(self: LazyRefs) -> any;
    def __len__(self: LazyRefs) -> int;
    def __bool__(self: LazyRefs) -> bool;
    def __iter__(self: LazyRefs) -> any;
    def __getitem__(self: LazyRefs, key: any) -> any;
    def __repr__(self: LazyRefs) -> str;
    def __eq__(self: LazyRefs, other: any) -> bool;
    def __contains__(self: LazyRefs, item: any) -> bool;
    def __reversed__(self: LazyRefs) -> any;
    def __add__(self: LazyRefs, other: any) -> any;
    def __setitem__(self: LazyRefs, key: any, value: any) -> None;
    def __delitem__(self: LazyRefs, key: any) -> None;
    def append(self: LazyRefs, item: any) -> None;
    def extend(self: LazyRefs, items: any) -> None;
    def insert(self: LazyRefs, i: int, item: any) -> None;
    def remove(self: LazyRefs, item: any) -> None;
    def pop(self: LazyRefs, i: int = -1) -> any;
    def clear(self: LazyRefs) -> None;
    def sort(self: LazyRefs, **kw: any) -> None;
    def reverse(self: LazyRefs) -> None;
    def index(self: LazyRefs, item: any, *a: any) -> int;
    def count(self: LazyRefs, item: any) -> int;
    def copy(self: LazyRefs) -> list[any];
}
