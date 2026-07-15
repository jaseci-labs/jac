# Unit tests for the na Jac-source synthesizer on the integer boundary tags
# (TAG_INT / TAG_UINT), against the jac-bridge-scalar bridge. Asserts the
# STRUCTURE of the generated source without invoking the native compiler (which
# needs the LLVM shim); the end-to-end "na output matches the CPython loader"
# check lives in na/scalar_conformance.jac, gated on a shim.
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }
import from _fixtures { scalar_so }


glob _SO = scalar_so(),
     _NAME = Path(_SO).name,
     _META = parse(read_jac_bridge_section(_SO));


test "integer params and returns annotate as int" {
    src = render_na_source(_META, _NAME).source;
    # ctor takes a signed int seed
    assert "def init(seed: int) {" in src;
    # signed return, signed param + return
    assert "def seed() -> int {" in src;
    assert "def add(x: int) -> int {" in src;
    # unsigned return / unsigned param + return / narrow width all annotate int
    assert "def magnitude() -> int {" in src;
    assert "def echo_u64(x: int) -> int {" in src;
    assert "def max_u64() -> int {" in src;
    assert "def low_byte() -> int {" in src;
    # fallible integer return is still `-> int` (the Err is raised, not returned)
    assert "def checked_div(divisor: int) -> int {" in src;
}


test "integer shims declare a u64 out-slot" {
    src = render_na_source(_META, _NAME).source;
    assert "def jac_scalar_Calc_add(" in src;
    # method self-handle + int param + out_int + out_err
    assert "handle: int," in src;
    assert "x: int," in src;
    assert "out_int: bytes," in src;
    # int returns never allocate a JacBuf or a bool slot
    assert "out_int = struct.pack(\"<Q\", 0);" in src;
}


test "signed returns are reinterpreted, unsigned are raw" {
    src = render_na_source(_META, _NAME).source;
    # TAG_INT: decode the u64 slot, then two's-complement reinterpret
    assert "iv = struct.unpack(\"<Q\", out_int)[0];" in src;
    assert "if iv >= 0x8000000000000000 {" in src;
    assert "return iv - 0x10000000000000000;" in src;
    # TAG_UINT: the slot is returned unsigned, no reinterpret
    assert "return struct.unpack(\"<Q\", out_int)[0];" in src;
}


test "integer methods are not skipped" {
    res = render_na_source(_META, _NAME);
    items = {s.item for s in res.skips};
    for name in [
        "Calc.seed",
        "Calc.add",
        "Calc.magnitude",
        "Calc.echo_u64",
        "Calc.max_u64",
        "Calc.low_byte",
        "Calc.checked_div"
    ] {
        assert name not in items , f"{name} was skipped: {items}";
    }
    # every method + ctor bridged
    assert res.bridged >= 8;
}


test "FN_STATIC associated fns are honestly skipped on na (gated)" {
    res = render_na_source(_META, _NAME);
    items = {s.item for s in res.skips};
    # The statics (`#[jac(assoc)]`) are CPython-only; na records them as skips so
    # coverage never silently drops the surface, and never emits them as callables.
    for name in ["Calc.from_sum", "Calc.answer", "Calc.parse"] {
        assert name in items , f"{name} must be a na skip: {items}";
    }
    reasons = {s.reason for s in res.skips};
    assert any(["FN_STATIC" in r for r in reasons]);
    # And the generated na source defines no static method for them.
    src = res.source;
    assert "def from_sum(" not in src;
    assert "def answer(" not in src;
}
