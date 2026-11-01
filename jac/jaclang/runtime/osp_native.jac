"""The OSP kernel's entry points for native code.

Generated native code reaches object-spatial programming only through the pub
`__jac_osp_*` functions here; their MIR signatures are `MIR_OSP_ABI` in
`compiler/backends/native/mir/runtime_abi.jac`. This unit drives the kernel
(`osp_kernel.jac`, `osp_graph.jac`) and holds what only native code needs: the
runtime record whose callbacks read the type tag from an object's header,
walker descriptors, and the references the graph and the walk stack pin.

A node or edge handle is the object's address; its type tag is the i64 at +8
(after the vtable pointer). The graph pins every node and edge it holds: a
connect retains its endpoints and edge, and `_sync` applies the retains and
releases the kernel queues for visits, walks and removed rows. This unit is
native-only and is never loaded as bytecode."""
obj OspNativeState {
    has runtime: (OspRuntime | None) = None,
        walkers: dict[int, OspWalkerDesc] = {},
        reports: (list[any] | None) = None,
        syncing: bool = False;
}

glob NATIVE: OspNativeState = OspNativeState(),
     TAG_OFFSET: int = 8,
     GENERIC_EDGE_SIZE: int = 16,
     GENERIC_EDGE_TAG: int = -3;

def _tag_of(h: any) -> int;

def _is_a(tag: int, base: int) -> bool;

def _node_desc(tag: int) -> OspNodeDesc;

def _on_complete(scope: OspWalkScope, ok: bool);

def _runtime -> OspRuntime;

def _walker_desc(tag: int) -> OspWalkerDesc;

def _pin_each(handles: list[int], hold: bool);

def _sync;

def:pub __jac_osp_register(tag: int, bases: list[int], walker: bool);

def:pub __jac_osp_slot(
    tag: int, is_entry: bool, trig_tag: int, fn: Callable[([any, any], any)]
);

def:pub __jac_osp_spawn(wlk: any, wtag: int, start: int) -> (list[any] | None);

def:pub __jac_osp_visit(targets: list[int], insert_loc: int) -> bool;

def:pub __jac_osp_report(val: any);

def:pub __jac_osp_disengage;

def:pub __jac_osp_skip;

def:pub __jac_osp_generic_edge -> int;

def:pub __jac_osp_connect(
    src: int, tgt: int, eobj: int, undirected: bool, edge_tag: int
);

def:pub __jac_osp_refs(origin: int, dir: int, edge_tag: int, edges_only: bool) -> list[int];

def:pub __jac_osp_refs_many(
    origins: list[int], dir: int, edge_tag: int, edges_only: bool
) -> list[int];

def:pub __jac_osp_refs_pred(
    origins: list[int],
    dir: int,
    edge_tag: int,
    edges_only: bool,
    pred: Callable[([int], bool)]
) -> list[int];

def:pub __jac_osp_filter(hs: list[int], pred: Callable[([int], bool)]) -> list[int];

def:pub __jac_osp_keep_toward(
    hs: list[int], origins: list[int], dir: int, edges_only: bool, wanted: list[int]
) -> list[int];

def:pub __jac_osp_disconnect(src: int, tgt: int, dir: int, edge_tag: int) -> bool;

def:pub __jac_osp_disconnect_pred(
    src: int, tgt: int, dir: int, edge_tag: int, pred: Callable[([int], bool)]
) -> bool;

def:pub __jac_osp_disconnect_many(
    srcs: list[int], tgts: list[int], dir: int, edge_tag: int
) -> bool;

def:pub __jac_osp_destroy(h: int);

def:pub __jac_osp_destroy_all(hs: list[int]);

def:pub __jac_osp_reclaimed(h: int, is_edge: bool);

def:pub __jac_osp_jid(h: int) -> str;

def:pub __jac_osp_is_a(tag: int, base: int) -> bool;
