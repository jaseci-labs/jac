"""Synthesizer wiring for the serde wide lane (FFI-LANES-PLAN 2.5 / 2.8).

`classify(TAG_WIDE)` -> `SlotKind.Wide`, and `_synth` turns a wide param/return
into a `JacValue` on the na surface: a wide return decodes the shim's msgpack
out-buffer via `msgpack_decode`, a wide param is `msgpack_encode`d into a bytes
payload passed through the foreign call (#7472). The shared codec
(`rust_bridge/_msgpack.jac`) is inlined into any bridge that uses a wide slot.

These build a synthetic bridge descriptor (no Rust toolchain / .so needed) and
assert on the rendered na source.
"""

import from jaclang.compiler.rust_bridge._blob {
    BridgeMeta,
    FnDesc,
    ParamDesc,
    TypeDesc,
    TAG_WIDE,
    TAG_INT,
    TAG_REF_BIT,
    TAG_VOID,
    FN_CTOR,
    FN_METHOD,
    KIND_OPAQUE
}
import from jaclang.compiler.rust_bridge._marshal {
    classify,
    classify_scalar,
    SlotKind
}
import from jaclang.compiler.rust_bridge._synth { render_na_source }


def _widget_meta -> BridgeMeta {
    ref0 = TAG_REF_BIT | 0;
    types = [
        TypeDesc(index=0, kind=KIND_OPAQUE, name="Widget", drop_sym="jac_t_widget_drop")
    ];
    fns = [
        FnDesc(
            index=0,
            name="new",
            sym="jac_t_widget_new",
            self_type=TAG_VOID,
            kind=FN_CTOR,
            throws=0,
            ret=ref0,
            params=[]
        ),
        FnDesc(
            index=1,
            name="echo",
            sym="jac_t_widget_echo",
            self_type=0,
            kind=FN_METHOD,
            throws=0,
            ret=TAG_WIDE,
            params=[ParamDesc(name="v", tag=TAG_WIDE)]
        ),
        FnDesc(
            index=2,
            name="pack",
            sym="jac_t_widget_pack",
            self_type=0,
            kind=FN_METHOD,
            throws=0,
            ret=TAG_WIDE,
            params=[]
        ),
        FnDesc(
            index=3,
            name="tally",
            sym="jac_t_widget_tally",
            self_type=0,
            kind=FN_METHOD,
            throws=0,
            ret=TAG_INT,
            params=[ParamDesc(name="v", tag=TAG_WIDE)]
        )
    ];
    return BridgeMeta(abi_version=1, module_name="test", types=types, fns=fns);
}


test "classify maps TAG_WIDE to SlotKind.Wide" {
    assert classify(TAG_WIDE).kind == SlotKind.Wide;
    # a wide value is a whole serde document, never a scalar leaf.
    assert classify_scalar(TAG_WIDE).kind == SlotKind.Unbridgeable;
}


test "wide param/return methods are bridged, not skipped" {
    nm = render_na_source(_widget_meta(), "libtest.so");
    assert nm.bridged == 4 , f"bridged={nm.bridged} skips={[s.item for s in nm.skips]}";
}


test "the msgpack codec is inlined into a wide bridge" {
    src = render_na_source(_widget_meta(), "libtest.so").source;
    assert "obj JacValue {" in src;
    assert "def msgpack_encode(vin: JacValue) -> bytes {" in src;
    assert "def msgpack_decode(base: int, total: int) -> JacValue {" in src;
}


test "wide return decodes the out-buffer to a JacValue" {
    src = render_na_source(_widget_meta(), "libtest.so").source;
    # na-facing signature returns a JacValue
    assert "def pack() -> JacValue {" in src;
    # the decode call threads the shim out-buffer pointer/len
    assert "_wv = msgpack_decode(rb[0], rb[1]);" in src;
    assert "return _wv;" in src;
}


test "wide param encodes a JacValue into the foreign call" {
    src = render_na_source(_widget_meta(), "libtest.so").source;
    # na-facing signature takes a JacValue
    assert "def echo(v: JacValue) -> JacValue {" in src;
    # shim decl carries the payload as bytes + an explicit length
    assert "        v: bytes," in src;
    assert "        v_len: int" in src;
    # body encodes before the foreign call
    assert "_enc_v = msgpack_encode(v);" in src;
}


test "wide param survives even with a non-wide return" {
    src = render_na_source(_widget_meta(), "libtest.so").source;
    assert "def tally(v: JacValue) -> int {" in src;
}
