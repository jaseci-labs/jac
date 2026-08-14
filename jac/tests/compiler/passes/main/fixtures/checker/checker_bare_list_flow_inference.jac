"""Flow-based element inference for empty bare-list literals (#6943 NA-7).

An empty `= []` (no annotation) adopts its element type from
the mutations that follow in the same scope: append/insert args, extend/`+=`
operands' element types, and index-store values. Only concrete scalar
evidence (int/float/str/bool) refines: literals are widened before joining,
None evidence beside a scalar collapses the join to the heterogeneous `any`
element, and any non-scalar contribution (`any`, Unknown, object instances)
aborts the inference so the list keeps its bare layout - dynamic values are
absence of information, not proof of heterogeneity, and native code (e.g.
the OSP kernel's handle lists) relies on the bare default. A list with no
mutation evidence stays bare; an explicit `list[T]` annotation still wins.
"""

obj Payload {
    has tag: int = 0;
}

def strs_join -> str {
    flow_strs = [];
    flow_strs.append("a");
    flow_strs.append("b");
    return "/".join(flow_strs);
}

def ints_stay_unboxed -> int {
    flow_ints = [];
    flow_ints.append(1);
    flow_ints.append(2);
    return len(flow_ints);
}

def mixed_collapses_to_any -> int {
    flow_mixed = [];
    flow_mixed.append(1);
    flow_mixed.append("two");
    return len(flow_mixed);
}

def extend_evidence -> int {
    flow_ext = [];
    flow_ext.extend(["x", "y"]);
    return len(flow_ext);
}

def insert_evidence -> int {
    flow_ins = [];
    flow_ins.insert(0, 2.5);
    return len(flow_ins);
}

def aug_add_evidence -> int {
    flow_aug = [];
    flow_aug += ["p", "q"];
    return len(flow_aug);
}

def index_store_evidence -> int {
    flow_idx = [];
    flow_idx.append("seed");
    flow_idx[0] = "stored";
    return len(flow_idx);
}

def unannotated_flow -> int {
    flow_unann = [];
    flow_unann.append("z");
    return len(flow_unann);
}

def none_only_stays_bare -> int {
    flow_none = [];
    flow_none.append(None);
    return len(flow_none);
}

def none_beside_scalar_boxes -> int {
    flow_nonemix = [];
    flow_nonemix.append(1);
    flow_nonemix.append(None);
    return len(flow_nonemix);
}

def any_evidence_stays_bare(v: any) -> int {
    flow_dyn = [];
    flow_dyn.append(v);
    return len(flow_dyn);
}

def any_poisons_scalar_evidence(v: any) -> int {
    flow_poison = [];
    flow_poison.append("s");
    flow_poison.append(v);
    return len(flow_poison);
}

def object_evidence_stays_bare -> int {
    flow_obj = [];
    flow_obj.append(Payload());
    return len(flow_obj);
}

def no_evidence_stays_bare -> int {
    flow_bare = [];
    return len(flow_bare);
}

def annotation_still_wins -> int {
    flow_pinned: list[int] = [];
    flow_pinned.append(7);
    return len(flow_pinned);
}

def multi_target_shares_evidence -> str {
    flow_multi_a = flow_multi_b=[];
    flow_multi_b.append("m");
    return "/".join(flow_multi_a);
}

def rebinding_conflates_conservatively -> int {
    flow_rebound = [];
    flow_rebound.append(1);
    flow_rebound = [];
    flow_rebound.append("a");
    return len(flow_rebound);
}
