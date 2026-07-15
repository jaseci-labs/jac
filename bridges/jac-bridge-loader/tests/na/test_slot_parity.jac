# FFI-LANES Phase 0.5 acceptance gate: GOLDEN slot/tag classification parity.
#
# Both in-compiler bridge generators dispatch every fn/param on the ABI-v1 tag
# word: `_synth.jac` (na source) and `_ctypes_codegen.jac` (ctypes loader).  The
# Phase 0.5 refactor extracts that dispatch into a single shared `SlotKind`
# layer.  This test pins the CURRENT (tag -> category) classification across all
# 10 shipped bridges so the extraction cannot silently change wire behavior:
#
#   * `classify(tag)` here is an INDEPENDENT oracle — it re-derives the category
#     straight from the raw ABI-v1 bit constants (TAG_*_BIT), NOT from the
#     generators' own helpers — so a drift in either generator is caught rather
#     than mirrored.
#   * The (tag -> category) table and the DISTINCT-tag set are hard-coded from
#     the values observed today; a lost, added, or reclassified tag fails CI.
#   * A cheap differential pins per-bridge (bridged, skips) counts from
#     render_na_source, and the silent "na-only" drop (the #[jac_error] `message`
#     method, dropped without a Skip) as fn_count - bridged - skips.
#
# Golden values were captured 2026-07-11 from bridges/target/{release,debug}.
# Runnable as a plain probe too (see scratchpad/probe.py in the authoring note):
#   PYTHONPATH=jac python -c "...iterate target/*/libjac_bridge_*.so..."
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob {
    parse,
    TAG_VOID,
    TAG_BOOL,
    TAG_INT,
    TAG_UINT,
    TAG_STR,
    TAG_FN,
    TAG_F64,
    TAG_BYTES,
    TAG_REF_BIT,
    TAG_OPT_BIT,
    TAG_MAP_BIT,
    TAG_LIST_BIT
}
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }


# The 10 crates shipped in the workspace (every bridge with a .jac_bridge
# section).  Order is deterministic; the plain `libjac_bridge.so` has no section
# and is intentionally excluded.
glob _STEMS: list[str] = [
         "libjac_bridge_async.so",
         "libjac_bridge_list.so",
         "libjac_bridge_map.so",
         "libjac_bridge_owning.so",
         "libjac_bridge_owning2.so",
         "libjac_bridge_owning3.so",
         "libjac_bridge_reentrant.so",
         "libjac_bridge_regex.so",
         "libjac_bridge_regex_v2.so",
         "libjac_bridge_scalar.so"
     ],
     # GOLDEN 1: every distinct ABI-v1 tag word observed across all 10 bridges, and
     # the category the shared SlotKind layer MUST assign it.  Keyed by the u32 tag.
     _EXPECTED_TAG_CATEGORY: dict[int, str] = {
         0x00000001: "bool",
         0x00000002: "int",
         0x00000003: "uint",
         0x00000004: "str",
         0x00000005: "fn",
         0x00000006: "f64",
         0x00000007: "bytes",
         0x40000007: "bytes",
         0x10000001: "list",
         0x10000002: "list",
         0x10000003: "list",
         0x10000004: "list",
         0x20000001: "map",
         0x20000002: "map",
         0x20000003: "map",
         0x20000004: "map",
         0x40000004: "str",
         0x80000000: "ref",
         0x80000001: "ref",
         0x80000004: "ref",
         0x80000005: "ref",
         0xC0000002: "ref",
         0xC0000003: "ref"
     },
     # GOLDEN 2: per-bridge (bridged, skips, fn_count) from render_na_source + parse.
     _EXPECTED_COUNTS: dict[str, tuple] = {
         "libjac_bridge_async.so": (5, 0, 6),
         "libjac_bridge_list.so": (7, 0, 8),
         "libjac_bridge_map.so": (7, 0, 8),
         "libjac_bridge_owning.so": (12, 0, 13),
         "libjac_bridge_owning2.so": (2, 0, 3),
         "libjac_bridge_owning3.so": (2, 0, 3),
         "libjac_bridge_reentrant.so": (7, 0, 8),
         "libjac_bridge_regex.so": (2, 0, 3),
         "libjac_bridge_regex_v2.so": (2, 0, 3),
         # scalar carries the f64 (TAG_F64) and bytes (TAG_BYTES) exemplars: na
         # bridges 10 methods and skips 5 -- add_f64 / echo_f32 (f64 param) and
         # seed_bytes / xor / maybe_bytes (the whole bytes lane) -- of 16 fns (the
         # 16th being the na-only #[jac_error] `message` drop).
         "libjac_bridge_scalar.so": (10, 5, 16)
     };


def _repo -> Path {
    # test_slot_parity.jac -> na -> tests -> jac-bridge-loader -> bridges -> repo
    return Path(__file__).resolve().parents[4];
}


def _resolve_sos -> dict[str, Path] {
    # First-found-wins per stem, preferring release over debug (same source, so
    # the metadata is build-independent). Mirrors the probe's dedup.
    repo = _repo();
    found = {};
    for stem in _STEMS {
        for build in ["release", "debug"] {
            p = repo / "bridges" / "target" / build / stem;
            if p.is_file() and stem not in found {
                found[stem] = p;
            }
        }
    }
    return found;
}


def classify(tag: int) -> str {
    # Independent oracle: category from the raw ABI-v1 tag word. Bit-order mirrors
    # the semantics both generators encode (opt is an orthogonal modifier stripped
    # before the base compare; map/list/ref are exclusive slot kinds).
    if tag == TAG_VOID {
        return "void";
    }
    if (tag & TAG_MAP_BIT) != 0 {
        return "map";
    }
    if (tag & TAG_LIST_BIT) != 0 {
        return "list";
    }
    base = tag & ~TAG_OPT_BIT;
    if (base & TAG_REF_BIT) != 0 and base != TAG_VOID {
        return "ref";
    }
    if base == TAG_STR {
        return "str";
    }
    if base == TAG_BOOL {
        return "bool";
    }
    if base == TAG_INT {
        return "int";
    }
    if base == TAG_UINT {
        return "uint";
    }
    if base == TAG_FN {
        return "fn";
    }
    if base == TAG_F64 {
        return "f64";
    }
    if base == TAG_BYTES {
        return "bytes";
    }
    return "UNKNOWN";
}


test "all 10 bridges are present in the build tree" {
    sos = _resolve_sos();
    missing = [
        s
        for s in _STEMS
        if s not in sos
    ];
    assert missing == [] , f"missing bridges (build them): {missing}";
    assert len(sos) == 10;
}


test "classify(tag) is stable for every tag observed across all bridges" {
    sos = _resolve_sos();
    observed = {};
    for stem in sorted(sos.keys()) {
        meta = parse(read_jac_bridge_section(str(sos[stem])));
        tags = set();
        for fd in meta.fns {
            tags.add(fd.ret);
            for p in fd.params {
                tags.add(p.tag);
            }
        }
        for t in tags {
            cat = classify(t);
            # No tag may classify as UNKNOWN — every wire slot must be covered.
            assert cat != "UNKNOWN" , f"{stem}: tag 0x{t:08X} unclassified";
            # The category must be a single-valued function of the tag: two
            # bridges that share a tag must agree (they always do, but this is
            # the property the refactor must preserve).
            if t in observed {
                assert observed[t] == cat;
            } else {
                observed[t] = cat;
            }
            # And it must match the hard-coded golden category.
            assert t in _EXPECTED_TAG_CATEGORY , f"{stem}: unexpected tag 0x{t:08X} (cat={cat})";
            assert _EXPECTED_TAG_CATEGORY[t] == cat , f"tag 0x{t:08X}: classify={cat} but golden={_EXPECTED_TAG_CATEGORY[
                t
            ]}";
        }
    }
    # GOLDEN: the DISTINCT tag set is exactly what we recorded — a lost or added
    # wire case is caught here even if it still classifies cleanly.
    assert set(observed.keys()) == set(_EXPECTED_TAG_CATEGORY.keys()) , f"distinct-tag drift: observed={sorted(
        observed.keys()
    )}";
    # Every golden tag must actually be exercised by some bridge.
    for gt in _EXPECTED_TAG_CATEGORY {
        assert gt in observed , f"golden tag 0x{gt:08X} no longer present";
    }
}


test "the set of categories is exactly the frozen SlotKind set" {
    # classify must partition tags into precisely these kinds (plus the unexercised
    # 'void'); a new or removed kind fails here. The scalar exemplar added "f64"
    # (TAG_F64) and "bytes" (TAG_BYTES) to the original 8.
    cats = set(_EXPECTED_TAG_CATEGORY.values());
    assert cats == {
        "bool",
        "int",
        "uint",
        "str",
        "fn",
        "list",
        "map",
        "ref",
        "f64",
        "bytes"
    };
}


test "per-bridge render_na_source counts match golden (bridged/skips/na-only)" {
    sos = _resolve_sos();
    for stem in sorted(sos.keys()) {
        meta = parse(read_jac_bridge_section(str(sos[stem])));
        nm = render_na_source(meta, stem);
        (exp_bridged, exp_skips, exp_fns) = _EXPECTED_COUNTS[stem];
        assert nm.bridged == exp_bridged , f"{stem}: bridged={nm.bridged} golden={exp_bridged}";
        assert len(nm.skips) == exp_skips , f"{stem}: skips={len(nm.skips)} golden={exp_skips}";
        assert len(meta.fns) == exp_fns , f"{stem}: fn_count={len(meta.fns)} golden={exp_fns}";
        # Differential: fn_count = bridged + skips + na_only, where na_only is the
        # silently-dropped #[jac_error] `message` method (not recorded as a Skip).
        # Frozen at 1 for every current bridge.
        na_only = len(meta.fns) - nm.bridged - len(nm.skips);
        assert na_only == 1 , f"{stem}: na_only drop={na_only} golden=1";
    }
}
