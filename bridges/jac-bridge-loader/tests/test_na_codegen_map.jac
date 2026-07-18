# Unit tests for the na Jac-source synthesizer on the map return tag
# (TAG_MAP_BIT | value_tag), against the jac-bridge-map bridge. The na backend now
# builds and returns a real dict[str, V] (see na/map_conformance.jac for the runtime
# na<->CPython equivalence proof); this asserts the SOURCE-level structure the
# synthesizer emits, without invoking the native compiler.
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


test "no map-returning method is skipped" {
    res = render_na_source(_META, _NAME);
    skipped = {s.item for s in res.skips};
    for name in _MAP_METHODS {
        assert name not in skipped , f"{name} should NOT be skipped: {skipped}";
    }
}


test "every map method emits a def with a dict return annotation" {
    src = render_na_source(_META, _NAME).source;
    for stem in ["counts", "big", "labels", "flags", "none", "checked"] {
        assert f"def {stem}(" in src , f"{stem} def missing";
        assert f"jac_mapdemo_Store_{stem}(" in src , f"{stem} shim missing";
    }
    # int/uint values -> dict[str, int]; labels -> dict[str, str]; flags -> dict[str, bool].
    assert "-> dict[str, int]" in src;
    assert "-> dict[str, str]" in src;
    assert "-> dict[str, bool]" in src;
}


test "the map decode reads count, key-length, key, then value per entry" {
    src = render_na_source(_META, _NAME).source;
    assert "__jac_bytes_from_raw(base, 4)" in src;
    assert "key = __jac_str_from_raw(base + off, klen);" in src;
    assert "result[key] = val;" in src;
}


test "the constructor bridges alongside the map methods" {
    res = render_na_source(_META, _NAME);
    assert "def init(n: int) {" in res.source;
    assert res.bridged >= 7 , f"expected >=7 bridged, got {res.bridged}";
}
