# Unit tests for the na Jac-source synthesizer on the map return tag
# (TAG_MAP_BIT | value_tag), against the jac-bridge-map bridge. The na backend
# cannot yet build or return a dict (no dict subscript-assign / dict-return ABI),
# so every HashMap<String, V> method must be SKIPPED cleanly with a map-specific
# reason rather than emitted (which would ICE the native compiler). The real dict
# marshaling lives on the CPython loader (test_map.jac); na dict-return support is
# the tracked follow-up. This asserts the synthesizer's structure without invoking
# the native compiler.
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }
import from _fixtures { map_so }


glob _SO = map_so(),
     _NAME = Path(_SO).name,
     _META = parse(read_jac_bridge_section(_SO)),
     _MAP_METHODS = [
         "Store.counts",
         "Store.big",
         "Store.labels",
         "Store.flags",
         "Store.none",
         "Store.checked"
     ];


test "every map-returning method is skipped, not emitted" {
    res = render_na_source(_META, _NAME);
    skipped = {s.item for s in res.skips};
    for name in _MAP_METHODS {
        assert name in skipped , f"{name} should be skipped: {skipped}";
    }
}


test "the skip reason names the na dict-return gap" {
    res = render_na_source(_META, _NAME);
    reasons = {s.item: s.reason for s in res.skips};
    for name in _MAP_METHODS {
        assert "dict returns are not yet supported" in reasons[name];
    }
}


test "the synthesized source has no map method bodies" {
    src = render_na_source(_META, _NAME).source;
    # None of the map methods emit a shim or a method def.
    for stem in ["counts", "big", "labels", "flags", "checked"] {
        assert f"def {stem}(" not in src;
        assert f"jac_mapdemo_Store_{stem}(" not in src;
    }
    # No map value ever names a dict return annotation.
    assert "-> dict" not in src;
}


test "the constructor still bridges despite the skipped methods" {
    res = render_na_source(_META, _NAME);
    # Store's ctor takes a u32 and returns Self — supported, so it survives.
    assert "def init(n: int) {" in res.source;
    assert res.bridged >= 1;
}
