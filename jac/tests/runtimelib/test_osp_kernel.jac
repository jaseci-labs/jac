"""Unit tests for the portable Object-Spatial traversal kernel
(jaclang.jac0core.osp_kernel), driven directly with toy descriptors and an
OspRuntime - no backend wiring. Pins the dispatch model the kernel provides to
sv/cl/na: DFS-recursive traversal with subtype dispatch, post-order exits,
opt-in visit-once via `scope.ignores`, and report collection."""

import from jaclang.jac0core.osp_kernel {
    Slot,
    WalkerDesc,
    NodeDesc,
    WalkScope,
    OspRuntime,
    osp_spawn,
    osp_visit,
    osp_disengage,
    osp_report,
    UNTYPED
}

obj TNode {
    has tag: int,
        name: str,
        neighbors: list = [];
}

obj TWalker {
    has log: list = [],
        tag: int = 10;
}

# Toy type system: Cafe (2) is-a Place (1); Spot (3) standalone; Walker (10).
glob _ancestors = {1: [1], 2: [2, 1], 3: [3], 10: [10]},
     _ndescs: dict = {},
     _last_reports: list = [];

def t_tag_of(h: any) -> int {
    return h.tag;
}

def t_is_a(tag: int, base: int) -> bool {
    return base in _ancestors.get(tag, []);
}

def t_node_desc(tag: int) -> NodeDesc {
    if tag in _ndescs {
        return _ndescs[tag];
    }
    return NodeDesc(type_tag=tag, entry=[], exit=[]);
}

def t_on_complete(scope: WalkScope, ok: bool) {
    _last_reports.clear();
    for r in scope.reports {
        _last_reports.append(r);
    }
}

def _runtime -> OspRuntime {
    return OspRuntime(
        tag_of=t_tag_of, is_a=t_is_a, node_desc=t_node_desc, on_complete=t_on_complete
    );
}

# --- abilities (lowered ability methods, here as plain functions) ---
def ab_place(w: any, here: any) {
    w.log.append("place:" + here.name);
    osp_report(here.name);
}

def ab_cafe(w: any, here: any) {
    w.log.append("cafe:" + here.name);
}

def ab_step(w: any, here: any) {
    w.log.append("step:" + here.name);
    osp_visit(here.neighbors);
}

def ab_step_with_exit(w: any, here: any) {
    w.log.append("entry:" + here.name);
    osp_visit(here.neighbors);
}

def ab_exit(w: any, here: any) {
    w.log.append("exit:" + here.name);
}

def ab_log_entry(w: any, here: any) {
    w.log.append("E:" + here.name);
    osp_visit(here.neighbors);
}

def ab_log_exit(w: any, here: any) {
    w.log.append("X:" + here.name);
}

def ab_stop(w: any, here: any) {
    w.log.append("stop:" + here.name);
    osp_visit(here.neighbors);
    if here.name == "B" {
        osp_disengage();
    }
}

def ab_node_any(here: any, visitor: any) {
    visitor.log.append("nany:" + here.name);
}

def ab_node_for_walker(here: any, visitor: any) {
    visitor.log.append("nforw:" + here.name);
}

test "osp kernel: subtyping dispatch and report collection" {
    wd = WalkerDesc(
        type_tag=10,
        entry=[Slot(trig_tag=1, fn=ab_place), Slot(trig_tag=2, fn=ab_cafe)],
        exit=[]
    );
    w = TWalker();
    # Spawn on a Cafe (tag 2): the Place-triggered ability fires via subtyping,
    # the Cafe-triggered ability fires by exact match.
    osp_spawn(_runtime(), w, wd, [TNode(tag=2, name="Bluebird")]);
    assert w.log == ["place:Bluebird", "cafe:Bluebird"];
    assert _last_reports == ["Bluebird"];
}

test "osp kernel: visit enqueues, DFS recursion through a chain" {
    a = TNode(tag=1, name="A");
    b = TNode(tag=1, name="B");
    c = TNode(tag=1, name="C");
    a.neighbors = [b];
    b.neighbors = [c];
    c.neighbors = [];
    wd = WalkerDesc(type_tag=10, entry=[Slot(trig_tag=1, fn=ab_step)], exit=[]);
    w = TWalker();
    osp_spawn(_runtime(), w, wd, [a]);
    assert w.log == ["step:A", "step:B", "step:C"];
}

test "osp kernel: branching tree - queue-FIFO entries, post-order exits" {
    a = TNode(tag=1, name="A");
    b = TNode(tag=1, name="B");
    c = TNode(tag=1, name="C");
    d = TNode(tag=1, name="D");
    a.neighbors = [b, c];
    b.neighbors = [d];
    c.neighbors = [];
    d.neighbors = [];
    wd = WalkerDesc(
        type_tag=10,
        entry=[Slot(trig_tag=1, fn=ab_log_entry)],
        exit=[Slot(trig_tag=1, fn=ab_log_exit)]
    );
    w = TWalker();
    osp_spawn(_runtime(), w, wd, [a]);
    # All visits share `scope.next`, so entries fire in queue-FIFO order across
    # branches (A->B->C->D, not A->B->D->C). The "depth-first" aspect lives in
    # the exit phase: structural post-order via recursion (D before C before B
    # before A). Matches the sv legacy engine's semantics.
    assert w.log == ["E:A", "E:B", "E:C", "E:D", "X:D", "X:C", "X:B", "X:A"];
}

test "osp kernel: exit abilities fire in post-order" {
    a = TNode(tag=1, name="A");
    b = TNode(tag=1, name="B");
    a.neighbors = [b];
    b.neighbors = [];
    wd = WalkerDesc(
        type_tag=10,
        entry=[Slot(trig_tag=1, fn=ab_step_with_exit)],
        exit=[Slot(trig_tag=1, fn=ab_exit)]
    );
    w = TWalker();
    osp_spawn(_runtime(), w, wd, [a]);
    # Entries fire on entry (pre-order), exits fire after all descendants (post-order).
    assert w.log == ["entry:A", "entry:B", "exit:B", "exit:A"];
}

test "osp kernel: disengage stops the walk" {
    a = TNode(tag=1, name="A");
    b = TNode(tag=1, name="B");
    c = TNode(tag=1, name="C");
    a.neighbors = [b];
    b.neighbors = [c];
    c.neighbors = [];
    wd = WalkerDesc(type_tag=10, entry=[Slot(trig_tag=1, fn=ab_stop)], exit=[]);
    w = TWalker();
    osp_spawn(_runtime(), w, wd, [a]);
    # Disengage at B drops the already-queued C.
    assert w.log == ["stop:A", "stop:B"];
}

test "osp kernel: node-side untyped and walker-typed entry abilities" {
    _ndescs[3] = NodeDesc(
        type_tag=3,
        entry=[
            Slot(trig_tag=UNTYPED, fn=ab_node_any),
            Slot(trig_tag=10, fn=ab_node_for_walker)
        ],
        exit=[]
    );
    wd = WalkerDesc(type_tag=10, entry=[], exit=[]);
    w = TWalker();
    osp_spawn(_runtime(), w, wd, [TNode(tag=3, name="P")]);
    # Untyped node ability (phase 2) then walker-typed node ability (phase 3).
    assert w.log == ["nany:P", "nforw:P"];
}
