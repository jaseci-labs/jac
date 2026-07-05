# Unit tests for the na Jac-source synthesizer on the list return tag
# (TAG_LIST_BIT | elem_tag), against the jac-bridge-list bridge. The na backend
# now builds and returns a real list[V] (see na/list_conformance.jac for the
# runtime na<->CPython equivalence proof); this asserts the SOURCE-level structure
# the synthesizer emits, without invoking the native compiler.
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }
import from _fixtures { list_so }


glob _SO = list_so(),
     _NAME = Path(_SO).name,
     _META = parse(read_jac_bridge_section(_SO)),
     _LIST_METHODS = [
         "Store.counts",
         "Store.big",
         "Store.labels",
         "Store.flags",
         "Store.none",
         "Store.checked"
     ];


test "no list-returning method is skipped" {
    res = render_na_source(_META, _NAME);
    skipped = {s.item for s in res.skips};
    for name in _LIST_METHODS {
        assert name not in skipped , f"{name} should NOT be skipped: {skipped}";
    }
}


test "every list method emits a def with a list return annotation" {
    src = render_na_source(_META, _NAME).source;
    for stem in ["counts", "big", "labels", "flags", "none", "checked"] {
        assert f"def {stem}(" in src , f"{stem} def missing";
        assert f"jac_listdemo_Store_{stem}(" in src , f"{stem} shim missing";
    }
    # The int/uint methods surface a list[int]; labels -> list[str]; flags -> list[bool].
    assert "-> list[int]" in src;
    assert "-> list[str]" in src;
    assert "-> list[bool]" in src;
}


test "the list decode reads count then per-element values from the raw buffer" {
    src = render_na_source(_META, _NAME).source;
    # The synthesized decoder pulls the wire image straight off the owned JacBuf
    # via the raw-pointer intrinsics, no dict/list ABI helper required.
    assert "__jac_bytes_from_raw(base, 4)" in src;
    assert "result.append(val)" in src;
    assert "out_buf = struct.pack(\"<QII\", 0, 0, 0);" in src;
}


test "the constructor bridges alongside the list methods" {
    res = render_na_source(_META, _NAME);
    assert "def init(n: int) {" in res.source;
    # ctor + 6 list methods all bridge.
    assert res.bridged >= 7 , f"expected >=7 bridged, got {res.bridged}";
}
