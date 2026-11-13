import from weakref { ReferenceType }
import from typing { cast }

obj _SvStore {
    has h_of_key: dict[any, int] = {},
        forgotten: set[int] = set(),
        region: int = 0;
}

class _AnchorRef(ReferenceType[Anchor]) {
    static has __slots__: tuple[str, ...] = ("store", "key", "handle", "is_edge");
    has store: _SvStore,
        key: any,
        handle: int,
        is_edge: bool;

    def __new__(
        cls: type[_AnchorRef], anchor: Anchor, store: _SvStore, key: any, handle: int
    ) -> _AnchorRef;

    def init(self: _AnchorRef, anchor: Anchor, store: _SvStore, key: any, handle: int);
}

glob _obj_of_h: list[_AnchorRef | None] = [None],
     _h_free: list[int] = [],
     _next_region: list[int] = [1],
     _tag_of_cls: dict[(type, int)] = {},
     _cls_of_tag_map: dict[(int, type)] = {},
     _fallback: _SvStore = _SvStore();

def _mem_or_ctx(mem: any) -> any;

def _store_for(m: any) -> _SvStore;

def _handle_of(st: _SvStore, anchor: Anchor) -> int;

def _collect_handle(dead_ref: ReferenceType[Anchor]) -> None;

def _mint(st: _SvStore, anchor: Anchor) -> int;

def handle_of(anchor: Anchor, mem: any = None) -> int;

def obj_of(h: int) -> (Anchor | None);

def tag_of_cls(cls: type) -> int;

def cls_of_tag(tag: int) -> (type | None);

def tag_for(edge_a: EdgeAnchor) -> int;

def _resolve(cand: (Anchor | None), m: any) -> (Anchor | None);

def sv_conn(
    src_a: NodeAnchor,
    tgt_a: NodeAnchor,
    edge_a: EdgeAnchor,
    is_undirected: bool,
    mem: any = None
) -> None;

def sv_live_edges(
    origin_a: NodeAnchor,
    dir_int: int,
    edge_type: (type | None),
    edges_only: bool,
    mem: any = None
) -> list[Anchor];

def sv_candidate_edges_between(
    src_a: NodeAnchor, tgt_a: NodeAnchor, dir_int: int, mem: any = None
) -> list[EdgeAnchor];

def _conn_hydrated(e: EdgeAnchor, m: any) -> None;

def sv_register_hydrated(
    node_a: NodeAnchor, mem: any = None, fetch_stubs: bool = False
) -> None;

def sv_edge_alive(edge_a: EdgeAnchor, mem: any = None) -> bool;

def _forget_handle(st: _SvStore, h: int);

def sv_forget_by_id(anchor_id: any, mem: any = None);

def sv_forget_edge(edge_a: EdgeAnchor, mem: any = None);

def sv_store_closed(mem: any) -> int;
