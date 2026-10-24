glob _isa: dict[int, set[int]] = {},
     _has_subs: set[int] = set();

def osp_register_type(tag: int, bases: list[int]) -> int;

def osp_is_a(tag: int, base: int) -> bool;

obj OspEdgeTypeDesc {
    has tag: int,
        factory: Callable[([], int)];
}

glob _edge_types: dict[str, OspEdgeTypeDesc] = {};

def osp_register_edge_type(name: str, tag: int, factory: Callable[([], int)]);

def osp_edge_type(name: str) -> OspEdgeTypeDesc;

def osp_new_edge(desc: OspEdgeTypeDesc) -> int;

glob _NO_ROWS: list[int] = [];

obj OspEdgeRow {
    has src: int,
        tgt: int,
        tag: int,
        handle: int,
        undirected: bool = False,
        live: bool = True,
        pos_out: int = -1,
        pos_in: int = -1;
}

obj OspAdj {
    has rows_out: list[int],
        rows_in: list[int],
        out: (dict[int, list[int]] | None) = None,
        inn: (dict[int, list[int]] | None) = None;
}

obj OspGraph {
    has adj: dict[int, OspAdj],
        rows: list[OspEdgeRow],
        free_rows: list[int],
        row_of: dict[int, int],
        dead: dict[int, int],
        regions: dict[int, list[int]],
        index_at: int = 8,
        tags_out: dict[int, dict[int, list[int]]] = {},
        tags_in: dict[int, dict[int, list[int]]] = {},
        holes_out: dict[int, int] = {},
        holes_in: dict[int, int] = {},
        jids: dict[int, str] = {},
        jid_next: int = 0,
        any_undirected: bool = False;

    def adj_of(h: int) -> OspAdj;
    def light_out(a: OspAdj) -> dict[int, list[int]];
    def light_in(a: OspAdj) -> dict[int, list[int]];
    def has_light(h: int) -> bool;
    def connect_light(src: int, tgt: int, tag: int, one_sided: bool) -> int;
    def light_remove_one(src: int, tgt: int, tag: int) -> bool;
    def light_pairs(h: int, outgoing: bool) -> list[int];
    def light_detach(h: int) -> int;
    def _drop_handle(lst: list[int], h: int) -> bool;
    def is_dead(h: int) -> bool;
    def has_edge(eobj: int) -> bool;

    has pin_refs: bool = False,
        unpinned: list[int] = [];

    def _row_alloc(src: int, tgt: int, tag: int, eobj: int, undirected: bool) -> int;
    def _row_retire(rid: int);
    def _compact(lst: list[int], outgoing: bool);
    def _slot_clear(
        lst: list[int], pos: int, rid: int, holes: int, outgoing: bool
    ) -> int;

    def _tag_drop(d: dict[int, list[int]], rid: int, outgoing: bool);
    def _drop_side(h: int, a: OspAdj, rid: int, outgoing: bool);
    def _add_side(h: int, a: OspAdj, rid: int, tag: int, outgoing: bool);
    def _live_rows(h: int, a: OspAdj, outgoing: bool) -> int;
    def region_reg(h: int, rgn: int);
    def _no_rows(h: int, a: OspAdj) -> bool;
    def connect(
        src: int,
        tgt: int,
        eobj: int,
        undirected: bool,
        tag: int,
        rgn_src: int,
        rgn_tgt: int
    ) -> int;

    def _build_index(h: int, lst: list[int], outgoing: bool);
    def _narrowed(h: int, outgoing: bool, want: int) -> bool;
    def _tag_matches(tag: int, want: int) -> bool;
    def _rows_for(h: int, a: OspAdj, outgoing: bool, want: int) -> list[int];
    def _collect(
        origin: int, dir: int, edge_tag: int, edges_only: bool, out: list[int]
    );

    def _dedup_tail(out: list[int], start: int, seen: set[int]);
    def refs_into(
        origin: int,
        dir: int,
        edge_tag: int,
        edges_only: bool,
        out: list[int],
        seen: set[int]
    );

    def refs(origin: int, dir: int, edge_tag: int, edges_only: bool) -> list[int];
    def refs_many(
        origins: list[int], dir: int, edge_tag: int, edges_only: bool
    ) -> list[int];

    def refs_edge_pred(
        origins: list[int],
        dir: int,
        edge_tag: int,
        edges_only: bool,
        pred: Callable[([int], bool)]
    ) -> list[int];

    def filter_handles(hs: list[int], pred: Callable[([int], bool)]) -> list[int];
    def refs_chain(
        origins: list[int], dirs: list[int], tags: list[int], edges_only: bool
    ) -> list[int];

    def conn_many(
        srcs: list[int],
        tgts: list[int],
        eobjs: list[int],
        undirected: bool,
        tag: int,
        rgn_src: int,
        rgn_tgt: int
    ) -> int;

    def keep_toward(
        hs: list[int], origins: list[int], dir: int, edges_only: bool, wanted: list[int]
    ) -> list[int];

    def jid_of(h: int, rgn: int = 0) -> str;
    def forget_jid(h: int);
    def edge_peer(eobj: int, origin: int) -> int;
    def _unlink(rid: int);
    def disconnect(eobj: int) -> bool;
    def _between_hits(
        from_h: int,
        to_h: int,
        edge_tag: int,
        any_row: bool,
        hits: list[int],
        hit_set: set[int]
    );

    def disconnect_between(src: int, tgt: int, dir: int, edge_tag: int) -> int;
    def disconnect_between_pred(
        src: int, tgt: int, dir: int, edge_tag: int, pred: Callable[([int], bool)]
    ) -> int;

    def light_disconnect_between(src: int, tgt: int, dir: int, edge_tag: int) -> int;
    def disconnect_between_many(
        srcs: list[int], tgts: list[int], dir: int, edge_tag: int
    ) -> int;

    def node_destroy(h: int) -> int;
    def destroy(h: int) -> int;
    def destroy_all(hs: list[int]) -> int;
    def _forget_index(h: int);
    def drop_node(h: int) -> int;
    def region_died(rgn: int) -> int;
}

def _hex16(v: int) -> str;

def _new_graph -> OspGraph;

glob DEFAULT_GRAPH: OspGraph = _new_graph();

def:pub osp_adj_fill(origin: int, dir: int, out: list[int]) -> int;

def:pub osp_adj_pairs(origin: int, dir: int) -> list[int];

def osp_has_edge(eh: int) -> int;

def osp_conn(
    src: int,
    tgt: int,
    eobj: int,
    undirected: int,
    edge_tag: int,
    rgn_src: int,
    rgn_tgt: int
) -> int;

def osp_refs(origin: int, dir: int, edge_tag: int, edges_only: int) -> list[int];

def osp_refs_many(
    origins: list[int], dir: int, edge_tag: int, edges_only: int
) -> list[int];

def osp_refs_edge_pred(
    origins: list[int],
    dir: int,
    edge_tag: int,
    edges_only: int,
    pred: Callable[([int], bool)]
) -> list[int];

def osp_filter(hs: list[int], pred: Callable[([int], bool)]) -> list[int];

def osp_refs_chain(
    origins: list[int], dirs: list[int], tags: list[int], edges_only: int
) -> list[int];

def osp_conn_many(
    srcs: list[int],
    tgts: list[int],
    eobjs: list[int],
    undirected: int,
    edge_tag: int,
    rgn_src: int,
    rgn_tgt: int
) -> int;

def osp_disconn_between_pred(
    src: int, tgt: int, dir: int, edge_tag: int, pred: Callable[([int], bool)]
) -> int;

def osp_disconn_between_many(
    srcs: list[int], tgts: list[int], dir: int, edge_tag: int
) -> int;

def osp_wrap1(x: int) -> list[int];

def osp_keep_toward(
    hs: list[int], origins: list[int], dir: int, edges_only: int, wanted: list[int]
) -> list[int];

def osp_jid(h: int, rgn: int) -> str;

def osp_edge_peer(edge_handle: int, origin: int) -> int;

def osp_conn_light(src: int, tgt: int, edge_tag: int, one_sided: int) -> int;

def osp_light_remove(src: int, tgt: int, edge_tag: int) -> int;

def osp_light_pairs(h: int, outgoing: int) -> list[int];

def osp_light_detach(h: int) -> int;

def osp_has_light(h: int) -> int;

def osp_light_disconn_between(src: int, tgt: int, dir: int, edge_tag: int) -> int;

def osp_drop_node(h: int) -> int;

def osp_forget_node(h: int);

def osp_forget_edge(h: int);

def osp_pin_refs;

def osp_unpinned_count -> int;

def osp_take_unpinned -> list[int];

def osp_disconn_between(src: int, tgt: int, dir: int, edge_tag: int) -> int;

def osp_disconnect(edge_handle: int) -> int;

def osp_is_dead(addr: int) -> int;

def osp_node_destroy(addr: int) -> int;

def osp_destroy(h: int) -> int;

def osp_destroy_all(hs: list[int]) -> int;

def osp_region_died(rgn: int) -> int;
