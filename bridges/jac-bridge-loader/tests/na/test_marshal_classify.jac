# Unit guard for the shared marshal layer (FFI-LANES Phase 0.5.1).
#
# `jaclang.compiler.rust_bridge._marshal.classify()` is the single source of
# truth that both bridge generators (na `_synth` + cty `_ctypes_codegen`) will
# consume in 0.5.2/0.5.3. These tests pin its Slot output against:
#   1. hand-computed expectations for every synthetic tag shape (incl. the
#      decision-order corners: container bits survive tag_base, ref != VOID,
#      OPT is an orthogonal flag not a variant), and
#   2. every tag value actually observed across the built reference .so bridges
#      (regex / owning / map / list / scalar / async) -- asserting classify()
#      never raises and never falls to Unbridgeable for a real, known tag.
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob {
    parse,
    TAG_BOOL,
    TAG_INT,
    TAG_UINT,
    TAG_STR,
    TAG_FN,
    TAG_VOID,
    TAG_REF_BIT,
    TAG_OPT_BIT,
    TAG_SHARED_BIT,
    TAG_BORROW_BIT,
    TAG_MAP_BIT,
    TAG_LIST_BIT
}
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._marshal {
    classify,
    classify_scalar,
    SlotKind,
    STATUS_OK,
    STATUS_ERR,
    STATUS_PANIC,
    STATUS_CB_ERR
}


def _built_sos -> list {
    repo = Path(__file__).resolve().parents[4];
    out = [];
    for stem in [
        "libjac_bridge_owning.so",
        "libjac_bridge_regex.so",
        "libjac_bridge_regex_v2.so",
        "libjac_bridge_map.so",
        "libjac_bridge_list.so",
        "libjac_bridge_scalar.so",
        "libjac_bridge_async.so"
    ] {
        for build in ["release", "debug"] {
            p = repo / "bridges" / "target" / build / stem;
            if p.is_file() {
                out.append(p);
                break;
            }
        }
    }
    return out;
}


test "status constants homed here" {
    # _blob.jac does not define these; _marshal is their canonical home.
    assert STATUS_OK == 0;
    assert STATUS_ERR == 1;
    assert STATUS_PANIC == 2;
    assert STATUS_CB_ERR == 3;
}


test "scalar tags classify to their variants" {
    assert classify(TAG_STR).kind == SlotKind.Str;
    assert classify(TAG_BOOL).kind == SlotKind.Bool;
    assert classify(TAG_INT).kind == SlotKind.Int;
    assert classify(TAG_UINT).kind == SlotKind.Uint;
    assert classify(TAG_FN).kind == SlotKind.Callback;
    assert classify(TAG_VOID).kind == SlotKind.Void;
    # No modifiers on a bare scalar.
    s = classify(TAG_INT);
    assert s.is_opt == False;
    assert s.ref_index == -1;
    assert s.value is None;
}


test "opt is an orthogonal flag, not a variant" {
    # Option<str> keeps the Str variant and only flips is_opt (DRIFT-R2/R4).
    s = classify(TAG_STR | TAG_OPT_BIT);
    assert s.kind == SlotKind.Str;
    assert s.is_opt == True;
    b = classify(TAG_BOOL | TAG_OPT_BIT);
    assert b.kind == SlotKind.Bool;
    assert b.is_opt == True;
    # VOID never carries opt (Void has no null payload).
    assert classify(TAG_VOID).is_opt == False;
}


test "opaque ref carries index and honors opt" {
    r = classify(TAG_REF_BIT | 7);
    assert r.kind == SlotKind.OpaqueRef;
    assert r.ref_index == 7;
    assert r.is_opt == False;
    o = classify(TAG_REF_BIT | TAG_OPT_BIT | 2);
    assert o.kind == SlotKind.OpaqueRef;
    assert o.ref_index == 2;
    assert o.is_opt == True;
    # ref_index 0 is a valid opaque handle, not VOID.
    z = classify(TAG_REF_BIT | 0);
    assert z.kind == SlotKind.OpaqueRef;
    assert z.ref_index == 0;
    # Owned (default) ref carries neither ownership bit.
    assert r.is_shared == False;
    assert r.is_borrowed == False;
}


test "ownership bits ride the opaque ref tag (Phase S)" {
    # A borrowed view: TAG_BORROW_BIT rides the ref tag; index and opt survive the
    # ownership-bit masking in tag_ref_index.
    b = classify(TAG_REF_BIT | TAG_BORROW_BIT | 1);
    assert b.kind == SlotKind.OpaqueRef;
    assert b.ref_index == 1;
    assert b.is_borrowed == True;
    assert b.is_shared == False;
    # A shared handle: TAG_SHARED_BIT rides the ref tag.
    s = classify(TAG_REF_BIT | TAG_SHARED_BIT | 3);
    assert s.kind == SlotKind.OpaqueRef;
    assert s.ref_index == 3;
    assert s.is_shared == True;
    assert s.is_borrowed == False;
    # Borrowed + optional: both flags coexist on one slot.
    ob = classify(TAG_REF_BIT | TAG_BORROW_BIT | TAG_OPT_BIT | 2);
    assert ob.is_borrowed == True;
    assert ob.is_opt == True;
    assert ob.ref_index == 2;
    # VOID (all bits set) must NOT be misread as a shared/borrowed ref.
    assert classify(TAG_VOID).kind == SlotKind.Void;
}


test "void is not misread as an opaque ref" {
    # 0xFFFFFFFF has the ref bit set but is VOID; tag_is_ref excludes it.
    assert classify(TAG_VOID).kind == SlotKind.Void;
}


test "container bits are tested before base decode" {
    # Map/list bits survive tag_base, so they must win over the base decode.
    m = classify(TAG_MAP_BIT | TAG_STR);
    assert m.kind == SlotKind.Map;
    assert m.value == SlotKind.Str;
    l = classify(TAG_LIST_BIT | TAG_INT);
    assert l.kind == SlotKind.List;
    assert l.value == SlotKind.Int;
    # Container value covers every scalar variant.
    assert classify(TAG_MAP_BIT | TAG_BOOL).value == SlotKind.Bool;
    assert classify(TAG_LIST_BIT | TAG_UINT).value == SlotKind.Uint;
    # Optional container: flag on the container, variant unchanged.
    om = classify(TAG_MAP_BIT | TAG_OPT_BIT | TAG_STR);
    assert om.kind == SlotKind.Map;
    assert om.is_opt == True;
    assert om.value == SlotKind.Str;
}


test "classify_scalar rejects non-scalars" {
    assert classify_scalar(TAG_STR).kind == SlotKind.Str;
    assert classify_scalar(TAG_UINT).kind == SlotKind.Uint;
    # fn / ref / void are not valid container element values.
    assert classify_scalar(TAG_FN).kind == SlotKind.Unbridgeable;
    assert classify_scalar(TAG_REF_BIT | 1).kind == SlotKind.Unbridgeable;
    assert classify_scalar(TAG_VOID).kind == SlotKind.Unbridgeable;
}


test "unknown tag is explicitly Unbridgeable" {
    # A base tag outside {str,bool,int,uint,fn,void,ref} rejects cleanly
    # instead of the old scattered `return None` / silent c_uint64 fall-through.
    assert classify(0x0000007F).kind == SlotKind.Unbridgeable;
}


test "every real bridge tag classifies without raising" {
    sos = _built_sos();
    assert len(sos) > 0;
    seen = 0;
    for so in sos {
        blob = read_jac_bridge_section(str(so));
        meta = parse(blob);
        for fn in meta.fns {
            tags = [fn.ret];
            for p in fn.params {
                tags.append(p.tag);
            }
            for tag in tags {
                s = classify(tag);
                # Every tag emitted by the real encoder is a known slot kind.
                assert s.kind != SlotKind.Unbridgeable;
                # OpaqueRef always resolves a non-negative index; Map/List
                # always carry a resolved scalar value kind.
                if s.kind == SlotKind.OpaqueRef {
                    assert s.ref_index >= 0;
                }
                if s.kind == SlotKind.Map or s.kind == SlotKind.List {
                    assert s.value is not None;
                    assert s.value != SlotKind.Unbridgeable;
                }
                seen += 1;
            }
        }
    }
    assert seen > 0;
}
