"""Flow-based element inference for empty bare-list literals (#6943 NA-7).

An empty `list = []` (bare annotation or none) adopts its element type from
the mutations that follow in the same scope: append/insert args, extend/`+=`
operands' element types, and index-store values. Literal types are widened
before joining; mixed evidence collapses to the heterogeneous `any` element;
a list with no mutation evidence stays bare; an explicit `list[T]` annotation
still wins over usage.
"""

def strs_join -> str {
    flow_strs: list = [];
    flow_strs.append("a");
    flow_strs.append("b");
    return "/".join(flow_strs);
}

def ints_stay_unboxed -> int {
    flow_ints: list = [];
    flow_ints.append(1);
    flow_ints.append(2);
    return len(flow_ints);
}

def mixed_collapses_to_any -> int {
    flow_mixed: list = [];
    flow_mixed.append(1);
    flow_mixed.append("two");
    return len(flow_mixed);
}

def extend_evidence -> int {
    flow_ext: list = [];
    flow_ext.extend(["x", "y"]);
    return len(flow_ext);
}

def insert_evidence -> int {
    flow_ins: list = [];
    flow_ins.insert(0, 2.5);
    return len(flow_ins);
}

def aug_add_evidence -> int {
    flow_aug: list = [];
    flow_aug += ["p", "q"];
    return len(flow_aug);
}

def index_store_evidence -> int {
    flow_idx: list = [];
    flow_idx.append("seed");
    flow_idx[0] = "stored";
    return len(flow_idx);
}

def unannotated_flow -> int {
    flow_unann = [];
    flow_unann.append("z");
    return len(flow_unann);
}

def none_evidence_boxes -> int {
    flow_none: list = [];
    flow_none.append(None);
    return len(flow_none);
}

def no_evidence_stays_bare -> int {
    flow_bare: list = [];
    return len(flow_bare);
}

def annotation_still_wins -> int {
    flow_pinned: list[int] = [];
    flow_pinned.append(7);
    return len(flow_pinned);
}
