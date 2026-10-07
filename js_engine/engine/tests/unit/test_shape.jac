"""
Smoke tests: Shape (hidden class) infrastructure — Phase 1 of
docs/shapes_impl_plan.md. Standalone: exercises runtime/shape.na.jac only.

Run with: jac run engine/tests/unit/test_shape.jac   (from js_engine root)
"""

import from engine.src.runtime.shape {
    Shape,
    SHAPE_ATTR_WRITABLE,
    SHAPE_ATTR_ENUMERABLE,
    SHAPE_ATTR_CONFIGURABLE,
    SHAPE_ATTR_ACCESSOR,
    SHAPE_ATTR_MASK,
    shape_root,
    shape_transition_add,
    shape_lookup,
    shape_attrs_of,
    shape_slot_of,
    shape_slot_count,
    shape_has,
    shape_keys,
    shape_key_count,
    shape_parent
}

glob ATTR_DEFAULT: int = SHAPE_ATTR_WRITABLE
         | SHAPE_ATTR_ENUMERABLE
         | SHAPE_ATTR_CONFIGURABLE,
     # Fake interned key ids
     K_X: int = 101,
     K_Y: int = 202,
     K_Z: int = 303;

with entry {
    # ── 1. Root shape ────────────────────────────────────────────────────────
    rt0: int = shape_root();
    ok: bool = True;
    if rt0 != 0 {
        ok = False;
        print("FAIL: rt0 id not 0");
    }
    if shape_root() != 0 {
        ok = False;
        print("FAIL: rt0 not idempotent");
    }
    if shape_slot_count(rt0) != 0 {
        ok = False;
        print("FAIL: rt0 slot_count");
    }
    if shape_key_count(rt0) != 0 {
        ok = False;
        print("FAIL: rt0 key_count");
    }
    if shape_lookup(rt0, K_X) != -1 {
        ok = False;
        print("FAIL: rt0 lookup should miss");
    }
    if shape_parent(rt0) != -1 {
        ok = False;
        print("FAIL: rt0 parent");
    }
    if ok {
        print("OK: root shape");
    }

    # ── 2. Single transition ─────────────────────────────────────────────────
    s_x: int = shape_transition_add(rt0, K_X, ATTR_DEFAULT);
    ok = True;
    if s_x <= 0 {
        ok = False;
        print("FAIL: transition id");
    }
    if shape_slot_count(s_x) != 1 {
        ok = False;
        print("FAIL: slot_count after x");
    }
    if shape_slot_of(s_x, K_X) != 0 {
        ok = False;
        print("FAIL: x slot");
    }
    if shape_attrs_of(s_x, K_X) != ATTR_DEFAULT {
        ok = False;
        print("FAIL: x attrs");
    }
    if not shape_has(s_x, K_X) {
        ok = False;
        print("FAIL: has x");
    }
    if shape_has(s_x, K_Y) {
        ok = False;
        print("FAIL: phantom y");
    }
    if shape_has(rt0, K_X) {
        ok = False;
        print("FAIL: rt0 polluted");
    }
    if ok {
        print("OK: single transition");
    }

    # ── 3. Transition sharing (the whole point) ──────────────────────────────
    # Two objects adding x then y must land on the SAME shape id.
    s_xy_a: int = shape_transition_add(s_x, K_Y, ATTR_DEFAULT);
    s_x_again: int = shape_transition_add(rt0, K_X, ATTR_DEFAULT);
    s_xy_b: int = shape_transition_add(s_x_again, K_Y, ATTR_DEFAULT);
    ok = True;
    if s_x_again != s_x {
        ok = False;
        print("FAIL: x transition not shared");
    }
    if s_xy_a != s_xy_b {
        ok = False;
        print("FAIL: xy transition not shared");
    }
    if shape_slot_count(s_xy_a) != 2 {
        ok = False;
        print("FAIL: xy slot_count");
    }
    if shape_slot_of(s_xy_a, K_X) != 0 {
        ok = False;
        print("FAIL: xy x slot");
    }
    if shape_slot_of(s_xy_a, K_Y) != 1 {
        ok = False;
        print("FAIL: xy y slot");
    }
    if ok {
        print("OK: transition sharing");
    }

    # ── 4. Order divergence: {y,x} is a DIFFERENT shape than {x,y} ───────────
    s_y: int = shape_transition_add(rt0, K_Y, ATTR_DEFAULT);
    s_yx: int = shape_transition_add(s_y, K_X, ATTR_DEFAULT);
    ok = True;
    if s_yx == s_xy_a {
        ok = False;
        print("FAIL: yx merged with xy");
    }
    if shape_slot_of(s_yx, K_Y) != 0 {
        ok = False;
        print("FAIL: yx y slot");
    }
    if shape_slot_of(s_yx, K_X) != 1 {
        ok = False;
        print("FAIL: yx x slot");
    }
    if ok {
        print("OK: order divergence");
    }
}

glob
     # ── 5. Attrs divergence forks a sibling edge ─────────────────────────────
     RO: int = SHAPE_ATTR_ENUMERABLE | SHAPE_ATTR_CONFIGURABLE;  # non-writable
with entry {
    s_x_ro: int = shape_transition_add(rt0, K_X, RO);
    ok = True;
    if s_x_ro == s_x {
        ok = False;
        print("FAIL: attrs not part of edge key");
    }
    if shape_attrs_of(s_x_ro, K_X) != RO {
        ok = False;
        print("FAIL: ro attrs");
    }
    if shape_attrs_of(s_x, K_X) != ATTR_DEFAULT {
        ok = False;
        print("FAIL: original attrs clobbered");
    }
    if ok {
        print("OK: attrs divergence");
    }

    # ── 6. Enumeration order (root→leaf) + cache stability ───────────────────
    s_xyz: int = shape_transition_add(s_xy_a, K_Z, ATTR_DEFAULT);
    keys1: list[int] = shape_keys(s_xyz);
    keys2: list[int] = shape_keys(s_xyz);  # cached second read
    ok = True;
    if len(keys1) != 3 {
        ok = False;
        print("FAIL: key count");
    }
    if keys1[0] != K_X or keys1[1] != K_Y or keys1[2] != K_Z {
        ok = False;
        print("FAIL: key order");
    }
    if len(keys2) != 3 {
        ok = False;
        print("FAIL: cached keys");
    }
    if shape_key_count(s_xyz) != 3 {
        ok = False;
        print("FAIL: key_count");
    }
    # keys of the mid-chain shape unaffected by the deeper transition
    kmid: list[int] = shape_keys(s_xy_a);
    if len(kmid) != 2 {
        ok = False;
        print("FAIL: mid-chain keys leaked");
    }
    if ok {
        print("OK: enumeration order");
    }
}

glob
     # ── 7. Accessor span: accessor property reserves two slots ───────────────
     ACC: int = SHAPE_ATTR_ACCESSOR | SHAPE_ATTR_ENUMERABLE | SHAPE_ATTR_CONFIGURABLE;
with entry {
    s_acc: int = shape_transition_add(s_x, K_Z, ACC);
    ok = True;
    if shape_slot_of(s_acc, K_Z) != 1 {
        ok = False;
        print("FAIL: accessor slot");
    }
    if shape_slot_count(s_acc) != 3 {
        ok = False;
        print("FAIL: accessor span");
    }
    if (shape_attrs_of(s_acc, K_Z) & SHAPE_ATTR_ACCESSOR) == 0 {
        ok = False;
        print("FAIL: accessor attr lost");
    }
    # data property after the accessor lands after the 2-slot span
    s_acc_y: int = shape_transition_add(s_acc, K_Y, ATTR_DEFAULT);
    if shape_slot_of(s_acc_y, K_Y) != 3 {
        ok = False;
        print("FAIL: slot after accessor span");
    }
    if shape_slot_count(s_acc_y) != 4 {
        ok = False;
        print("FAIL: slot_count after span");
    }
    if ok {
        print("OK: accessor span");
    }

    # ── 8. Parent chain ──────────────────────────────────────────────────────
    ok = True;
    if shape_parent(s_xyz) != s_xy_a {
        ok = False;
        print("FAIL: parent of xyz");
    }
    if shape_parent(s_xy_a) != s_x {
        ok = False;
        print("FAIL: parent of xy");
    }
    if shape_parent(s_x) != rt0 {
        ok = False;
        print("FAIL: parent of x");
    }
    if ok {
        print("OK: parent chain");
    }

    # ── 9. Deep chain stress (constructor with 64 fields) ────────────────────
    cur: int = rt0;
    fi: int = 0;
    while fi < 64 {
        cur = shape_transition_add(cur, 1000 + fi, ATTR_DEFAULT);
        fi = fi + 1;
    }
    # replay reaches the identical leaf shape
    cur2: int = rt0;
    fi = 0;
    while fi < 64 {
        cur2 = shape_transition_add(cur2, 1000 + fi, ATTR_DEFAULT);
        fi = fi + 1;
    }
    ok = True;
    if cur != cur2 {
        ok = False;
        print("FAIL: deep replay diverged");
    }
    if shape_slot_count(cur) != 64 {
        ok = False;
        print("FAIL: deep slot_count");
    }
    if shape_slot_of(cur, 1000) != 0 {
        ok = False;
        print("FAIL: deep first slot");
    }
    if shape_slot_of(cur, 1063) != 63 {
        ok = False;
        print("FAIL: deep last slot");
    }
    if shape_key_count(cur) != 64 {
        ok = False;
        print("FAIL: deep key count");
    }
    if ok {
        print("OK: deep chain");
    }

    print("shape (B1 Phase 1) tests done");
}
