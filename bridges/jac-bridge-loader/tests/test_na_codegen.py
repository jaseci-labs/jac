"""Unit tests for the na Jac-source synthesizer (_na_codegen).

These assert the STRUCTURE of the generated source without invoking the native
compiler (which needs the LLVM shim).  The end-to-end "generated source compiles
and runs natively" check lives in the na conformance suite, gated on a shim.
"""

from pathlib import Path

import pytest
from jac_bridge_loader._blob import BridgeMeta, parse
from jac_bridge_loader._elf import read_jac_bridge_section
from jac_bridge_loader._na_codegen import render_na_source


def _find_regex_so() -> Path | None:
    here = Path(__file__).resolve()
    for base in (here.parents[2], here.parents[3]):  # bridges/, repo/
        for build in ("release", "debug"):
            p = base / "target" / build / "libjac_bridge_regex.so"
            if p.is_file():
                return p
    return None


@pytest.fixture(scope="module")
def regex_meta() -> tuple[Path, BridgeMeta]:
    so = _find_regex_so()
    if so is None:
        pytest.skip("libjac_bridge_regex.so not built (run: cargo build --release)")
    return so, parse(read_jac_bridge_section(str(so)))


def _find_owning_so() -> Path | None:
    here = Path(__file__).resolve()
    for base in (here.parents[2], here.parents[3]):  # bridges/, repo/
        for build in ("release", "debug"):
            p = base / "target" / build / "libjac_bridge_owning.so"
            if p.is_file():
                return p
    return None


@pytest.fixture(scope="module")
def owning_meta() -> tuple[Path, BridgeMeta]:
    so = _find_owning_so()
    if so is None:
        pytest.skip("libjac_bridge_owning.so not built (run: cargo build --release)")
    return so, parse(read_jac_bridge_section(str(so)))


def test_generates_opaque_obj_and_ctor(regex_meta: tuple[Path, BridgeMeta]) -> None:
    so, meta = regex_meta
    res = render_na_source(meta, so.name)
    src = res.source
    assert "obj Regex {" in src
    assert "has __handle: int = 0;" in src
    assert "has __closed: bool = True;" in src
    assert "def init(pattern: str) {" in src
    assert "def is_match(text: str) -> bool {" in src
    assert "def __del__() {" in src


def test_marshaling_uses_strlen_and_struct(regex_meta: tuple[Path, BridgeMeta]) -> None:
    so, meta = regex_meta
    src = render_na_source(meta, so.name).source
    # string IN goes through libc strlen, not len()
    assert 'import from "libc.so.6" {' in src
    assert "def strlen(s: str) -> int;" in src
    assert "strlen(pattern)" in src
    assert "strlen(text)" in src
    # never the bare na len() on a str param (strlen(...) is fine — hence the space)
    assert " len(" not in src and "(len(" not in src
    # out-params via struct.pack / struct.unpack
    assert 'struct.pack("<Q", 0)' in src
    assert 'struct.pack("<B", 0)' in src
    assert 'struct.unpack("<Q", out_h)[0]' in src
    assert 'struct.unpack("<B", out_b)[0] != 0' in src


def test_foreign_shims_and_drop_declared(regex_meta: tuple[Path, BridgeMeta]) -> None:
    so, meta = regex_meta
    src = render_na_source(meta, so.name).source
    assert f'import from "{so.name}" {{' in src
    assert "def jac_regex_Regex_new(" in src
    assert "def jac_regex_Regex_is_match(" in src
    assert "def jac_regex_Regex_drop(handle: int) -> None;" in src
    assert "def jac_regex_error_drop(err_handle: int) -> None;" in src
    # dtor calls the drop shim
    assert "jac_regex_Regex_drop(self.__handle);" in src


def test_error_message_is_read_into_raised_exception(
    regex_meta: tuple[Path, BridgeMeta],
) -> None:
    so, meta = regex_meta
    res = render_na_source(meta, so.name)
    src = res.source
    # RegexError.message() is no longer skipped — it's consumed to build the
    # real Rust error text on the raised exception (matching the CPython loader).
    items = {s.item for s in res.skips}
    assert "RegexError.message" not in items
    # message() stays off the obj surface (errors are exceptions, not handles).
    assert "def message(" not in src
    # the error path reads the JacBuf via the na intrinsic, frees it, and raises
    # the decoded text rather than a synthetic "failed with status N".
    assert "jac_regex_error_message(err_h, mbuf, mben)" in src
    assert "__jac_str_from_raw(mb[0], mb[1])" in src
    assert "jac_regex_free_buf(mb[0], mb[1] | (mb[2] << 32))" in src
    assert "raise ValueError(emsg);" in src


def test_free_buf_reconstructs_jacbuf_by_value(
    regex_meta: tuple[Path, BridgeMeta],
) -> None:
    so, meta = regex_meta
    src = render_na_source(meta, so.name).source
    # A #[repr(C)] {ptr:u64, len:u32, cap:u32} is two SysV eightbytes; free_buf
    # (by-value) is declared + called as two ints (ptr, len|cap<<32).
    assert "def jac_regex_free_buf(buf_ptr: int, buf_lencap: int) -> None;" in src


def test_no_fragile_from_handle(regex_meta: tuple[Path, BridgeMeta]) -> None:
    so, meta = regex_meta
    # _from_handle would call the arg-taking ctor with no args; never emit it.
    assert "_from_handle" not in render_na_source(meta, so.name).source


# ── nullable Option<Ref> returns (owning bridge): bridged via adopt-ctor ──────


def test_opt_ref_returns_bridge_via_adopt_ctor(
    owning_meta: tuple[Path, BridgeMeta],
) -> None:
    so, meta = owning_meta
    res = render_na_source(meta, so.name)
    # find / captures return Option<opaque handle> — now bridged: na lowers the
    # `T | None` union to a nullable pointer, so a null handle on OK status crosses
    # in-band as a Jac None (proven by the xmod_unionret native fixture).
    items = {s.item for s in res.skips}
    assert "Regex.find" not in items
    assert "Regex.captures" not in items
    src = res.source
    # their shims are now emitted...
    assert "def jac_owning_Regex_find(" in src
    assert "def jac_owning_Regex_captures(" in src
    # ...with a nullable union return type,
    assert "def find(text: str) -> OwnedMatch | None {" in src
    assert "def captures(text: str) -> OwnedCaptures | None {" in src
    # ...a null-handle -> None mapping on the raw out-slot,
    assert 'rh = struct.unpack("<Q", out_h)[0];' in src
    assert "if rh == 0 {" in src
    assert "return None;" in src
    # ...and a bare-construct of the wrapper via its adopt-ctor.
    assert "return OwnedMatch(rh);" in src
    assert "return OwnedCaptures(rh);" in src


def test_adopt_ctor_and_wrapper_declared_before_producer(
    owning_meta: tuple[Path, BridgeMeta],
) -> None:
    so, meta = owning_meta
    src = render_na_source(meta, so.name).source
    # a by-handle-produced wrapper (no real Rust ctor) gets a same-class adopt-ctor
    # that stores the raw handle — the proven golden-spike init shape.
    assert "def init(raw: int) {" in src
    assert "self.__handle = raw;" in src
    assert "self.__closed = False;" in src
    # adoption targets are declared BEFORE their producer, since the na type
    # resolver is declaration-order sensitive.
    order = [ln.split()[1] for ln in src.splitlines() if ln.startswith("obj ")]
    assert order.index("OwnedMatch") < order.index("Regex")
    assert order.index("OwnedCaptures") < order.index("Regex")
    # NESTED dependency: OwnedCaptures.name_match produces an OwnedMatch, so the
    # synthesizer's topological emit order must place OwnedMatch before the
    # OwnedCaptures that produces it (not merely before the root Regex).
    assert order.index("OwnedMatch") < order.index("OwnedCaptures")


def test_opt_str_return_bridges_none_distinct_from_empty(
    owning_meta: tuple[Path, BridgeMeta],
) -> None:
    so, meta = owning_meta
    res = render_na_source(meta, so.name)
    # Option<str> is now bridged on na: str|None narrowing + concat is verified
    # natively, so a null JacBuf.ptr crosses in-band as None, kept DISTINCT from a
    # non-null empty "" (a present group that matched zero chars).
    items = {s.item for s in res.skips}
    assert "OwnedCaptures.name" not in items
    src = res.source
    assert "def jac_owning_OwnedCaptures_name(" in src
    # nullable str return type,
    assert "def name(name: str) -> str | None {" in src
    # a null-ptr -> None mapping (NOT "" — that would conflate absent with empty),
    assert "if rb[0] == 0 {" in src
    assert "return None;" in src
    # and a real decode of a non-null buffer (empty or not).
    assert "rs = __jac_str_from_raw(rb[0], rb[1]);" in src


def test_non_nullable_methods_still_bridge(
    owning_meta: tuple[Path, BridgeMeta],
) -> None:
    so, meta = owning_meta
    src = render_na_source(meta, so.name).source
    # The plain (non-Option) surface is unaffected by OPT-bit handling.
    assert "obj Regex {" in src
    assert "def is_match(text: str) -> bool {" in src
    assert "jac_owning_Regex_is_match(" in src
    # OwnedMatch.as_str is a plain String return -> bridged, annotated `-> str`
    # (na needs the annotation or it types the result as its i64 fallback and
    # miscompiles string concatenation of the returned value).
    assert "def as_str() -> str {" in src


def test_nested_wrapper_producer_bridges(
    owning_meta: tuple[Path, BridgeMeta],
) -> None:
    so, meta = owning_meta
    res = render_na_source(meta, so.name)
    # name_match is a reader ON a wrapper (OwnedCaptures) that PRODUCES another
    # wrapper (OwnedMatch) — the nested owning-wrapper case. It bridges through the
    # exact same Option<Ref> adopt-ctor path as Regex.find, just one level deeper.
    items = {s.item for s in res.skips}
    assert "OwnedCaptures.name_match" not in items
    src = res.source
    assert "def jac_owning_OwnedCaptures_name_match(" in src
    # nullable by-handle return of the OTHER wrapper type, bare-constructed via
    # OwnedMatch's adopt-ctor — the producer lives on OwnedCaptures, not Regex.
    assert "def name_match(name: str) -> OwnedMatch | None {" in src
    assert "return OwnedMatch(rh);" in src
    # the name_match producer sits inside the OwnedCaptures obj body.
    oc_body = src.split("obj OwnedCaptures {", 1)[1].split("obj ", 1)[0]
    assert "def name_match(" in oc_body
