# Unit tests for the na Jac-source synthesizer (_synth / render_na_source).
#
# These assert the STRUCTURE of the generated source without invoking the native
# compiler (which needs the LLVM shim).  The end-to-end "generated source compiles
# and runs natively" check lives in the na conformance suite, gated on a shim.
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }
import from _fixtures { regex_so, owning_so }


glob _REGEX_SO = regex_so(),
     _REGEX_NAME = Path(_REGEX_SO).name,
     _REGEX_META = parse(read_jac_bridge_section(_REGEX_SO));

glob _OWNING_SO = owning_so(),
     _OWNING_NAME = Path(_OWNING_SO).name,
     _OWNING_META = parse(read_jac_bridge_section(_OWNING_SO));


test "generates opaque obj and ctor" {
    res = render_na_source(_REGEX_META, _REGEX_NAME);
    src = res.source;
    assert "obj Regex {" in src;
    assert "has __handle: int = 0;" in src;
    assert "has __closed: bool = True;" in src;
    assert "def init(pattern: str) {" in src;
    assert "def is_match(text: str) -> bool {" in src;
    assert "def __del__() {" in src;
}


test "marshaling uses strlen and struct" {
    src = render_na_source(_REGEX_META, _REGEX_NAME).source;
    # string IN goes through libc strlen, not len()
    assert 'import from "libc.so.6" {' in src;
    assert "def strlen(s: str) -> int;" in src;
    assert "strlen(pattern)" in src;
    assert "strlen(text)" in src;
    # never the bare na len() on a str param (strlen(...) is fine — hence the space)
    assert " len(" not in src and "(len(" not in src;
    # out-params via struct.pack / struct.unpack
    assert 'struct.pack("<Q", 0)' in src;
    assert 'struct.pack("<B", 0)' in src;
    assert 'struct.unpack("<Q", out_h)[0]' in src;
    assert 'struct.unpack("<B", out_b)[0] != 0' in src;
}


test "foreign shims and drop declared" {
    src = render_na_source(_REGEX_META, _REGEX_NAME).source;
    assert f'import from "{_REGEX_NAME}" {{' in src;
    assert "def jac_regex_Regex_new(" in src;
    assert "def jac_regex_Regex_is_match(" in src;
    assert "def jac_regex_Regex_drop(handle: int) -> None;" in src;
    assert "def jac_regex_error_drop(err_handle: int) -> None;" in src;
    # dtor calls the drop shim
    assert "jac_regex_Regex_drop(self.__handle);" in src;
}


test "error message is read into raised exception" {
    res = render_na_source(_REGEX_META, _REGEX_NAME);
    src = res.source;
    # RegexError.message() is no longer skipped — it's consumed to build the
    # real Rust error text on the raised exception (matching the CPython loader).
    items = {s.item for s in res.skips};
    assert "RegexError.message" not in items;
    # message() stays off the obj surface (errors are exceptions, not handles).
    assert "def message(" not in src;
    # the error path reads the JacBuf via the na intrinsic, frees it, and raises
    # the decoded text rather than a synthetic "failed with status N".
    assert "jac_regex_error_message(err_h, mbuf, mben)" in src;
    assert "__jac_str_from_raw(mb[0], mb[1])" in src;
    assert "jac_regex_free_buf(mb[0], mb[1] | (mb[2] << 32))" in src;
    assert "raise ValueError(emsg);" in src;
}


test "free buf reconstructs jacbuf by value" {
    src = render_na_source(_REGEX_META, _REGEX_NAME).source;
    # A #[repr(C)] {ptr:u64, len:u32, cap:u32} is two SysV eightbytes; free_buf
    # (by-value) is declared + called as two ints (ptr, len|cap<<32).
    assert "def jac_regex_free_buf(buf_ptr: int, buf_lencap: int) -> None;" in src;
}


test "no fragile from_handle" {
    # _from_handle would call the arg-taking ctor with no args; never emit it.
    assert "_from_handle" not in render_na_source(_REGEX_META, _REGEX_NAME).source;
}


# ── nullable Option<Ref> returns (owning bridge): bridged via adopt-ctor ──────
test "opt ref returns bridge via adopt ctor" {
    res = render_na_source(_OWNING_META, _OWNING_NAME);
    # find / captures return Option<opaque handle> — now bridged: na lowers the
    # `T | None` union to a nullable pointer, so a null handle on OK status crosses
    # in-band as a Jac None (proven by the xmod_unionret native fixture).
    items = {s.item for s in res.skips};
    assert "Regex.find" not in items;
    assert "Regex.captures" not in items;
    src = res.source;
    # their shims are now emitted...
    assert "def jac_owning_Regex_find(" in src;
    assert "def jac_owning_Regex_captures(" in src;
    # ...with a nullable union return type,
    assert "def find(text: str) -> OwnedMatch | None {" in src;
    assert "def captures(text: str) -> OwnedCaptures | None {" in src;
    # ...a null-handle -> None mapping on the raw out-slot,
    assert 'rh = struct.unpack("<Q", out_h)[0];' in src;
    assert "if rh == 0 {" in src;
    assert "return None;" in src;
    # ...and a bare-construct of the wrapper via its adopt-ctor.
    assert "return OwnedMatch(rh);" in src;
    assert "return OwnedCaptures(rh);" in src;
}


test "adopt ctor and wrapper declared before producer" {
    src = render_na_source(_OWNING_META, _OWNING_NAME).source;
    # a by-handle-produced wrapper (no real Rust ctor) gets a same-class adopt-ctor
    # that stores the raw handle — the proven golden-spike init shape.
    assert "def init(raw: int) {" in src;
    assert "self.__handle = raw;" in src;
    assert "self.__closed = False;" in src;
    # adoption targets are declared BEFORE their producer, since the na type
    # resolver is declaration-order sensitive.
    order = [
        ln.split()[1]
        for ln in src.splitlines()
        if ln.startswith("obj ")
    ];
    assert order.index("OwnedMatch") < order.index("Regex");
    assert order.index("OwnedCaptures") < order.index("Regex");
    # NESTED dependency: OwnedCaptures.name_match produces an OwnedMatch, so the
    # synthesizer's topological emit order must place OwnedMatch before the
    # OwnedCaptures that produces it (not merely before the root Regex).
    assert order.index("OwnedMatch") < order.index("OwnedCaptures");
}


test "opt str return bridges none distinct from empty" {
    res = render_na_source(_OWNING_META, _OWNING_NAME);
    # Option<str> is now bridged on na: str|None narrowing + concat is verified
    # natively, so a null JacBuf.ptr crosses in-band as None, kept DISTINCT from a
    # non-null empty "" (a present group that matched zero chars).
    items = {s.item for s in res.skips};
    assert "OwnedCaptures.name" not in items;
    src = res.source;
    assert "def jac_owning_OwnedCaptures_name(" in src;
    # nullable str return type,
    assert "def name(name: str) -> str | None {" in src;
    # a null-ptr -> None mapping (NOT "" — that would conflate absent with empty),
    assert "if rb[0] == 0 {" in src;
    assert "return None;" in src;
    # and a real decode of a non-null buffer (empty or not).
    assert "rs = __jac_str_from_raw(rb[0], rb[1]);" in src;
}


test "non nullable methods still bridge" {
    src = render_na_source(_OWNING_META, _OWNING_NAME).source;
    # The plain (non-Option) surface is unaffected by OPT-bit handling.
    assert "obj Regex {" in src;
    assert "def is_match(text: str) -> bool {" in src;
    assert "jac_owning_Regex_is_match(" in src;
    # OwnedMatch.as_str is a plain String return -> bridged, annotated `-> str`
    # (na needs the annotation or it types the result as its i64 fallback and
    # miscompiles string concatenation of the returned value).
    assert "def as_str() -> str {" in src;
}


test "nested wrapper producer bridges" {
    res = render_na_source(_OWNING_META, _OWNING_NAME);
    # name_match is a reader ON a wrapper (OwnedCaptures) that PRODUCES another
    # wrapper (OwnedMatch) — the nested owning-wrapper case. It bridges through the
    # exact same Option<Ref> adopt-ctor path as Regex.find, just one level deeper.
    items = {s.item for s in res.skips};
    assert "OwnedCaptures.name_match" not in items;
    src = res.source;
    assert "def jac_owning_OwnedCaptures_name_match(" in src;
    # nullable by-handle return of the OTHER wrapper type, bare-constructed via
    # OwnedMatch's adopt-ctor — the producer lives on OwnedCaptures, not Regex.
    assert "def name_match(name: str) -> OwnedMatch | None {" in src;
    assert "return OwnedMatch(rh);" in src;
    # the name_match producer sits inside the OwnedCaptures obj body.
    oc_body = src.split("obj OwnedCaptures {", 1)[1].split("obj ", 1)[0];
    assert "def name_match(" in oc_body;
}


test "cursor and drain bridge" {
    res = render_na_source(_OWNING_META, _OWNING_NAME);
    items = {s.item for s in res.skips};

    # CURSOR: Regex.find_iter -> OwnedMatches (a plain, non-nullable handle: a
    # cursor is always constructed), whose next() pulls Option<OwnedMatch>.
    assert "Regex.find_iter" not in items;
    assert "OwnedMatches.next" not in items;
    src = res.source;
    assert "def find_iter(text: str) -> OwnedMatches {" in src;
    # next is an ordinary Opt(Ref) return, bare-constructed via OwnedMatch's
    # adopt-ctor — no new machinery, just the nested-share pattern per pull.
    om_next_body = src.split("obj OwnedMatches {", 1)[1].split("obj ", 1)[0];
    assert "def next() -> OwnedMatch | None {" in om_next_body;
    assert "return OwnedMatch(rh);" in om_next_body;

    # DRAIN: Regex.split -> OwnedSplit, whose next() drains Option<Str>.
    assert "Regex.split" not in items;
    assert "OwnedSplit.next" not in items;
    assert "def split(text: str) -> OwnedSplit {" in src;
    os_next_body = src.split("obj OwnedSplit {", 1)[1].split("obj ", 1)[0];
    assert "def next() -> str | None {" in os_next_body;

    # Topological emit order: each product precedes its producing cursor.
    order = [
        ln.split()[1]
        for ln in src.splitlines()
        if ln.startswith("obj ")
    ];
    assert order.index("OwnedMatch") < order.index("OwnedMatches");  # next's product
    assert order.index("OwnedMatches") < order.index("Regex");  # find_iter's product
    assert order.index("OwnedSplit") < order.index("Regex");  # split's product
}


test "callback bridge" {
    # The CALLBACK vertical: replace_all takes a TAG_FN param as an int, but under
    # the ctx-carrying ABI that int is the ADDRESS of a two-word {call, ctx} record
    # (not a bare fn pointer) — the record is built at the na CALL SITE, where the
    # backend lowers a `lambda` arg to a trampoline + env (see _codegen_callback_arg;
    # end-to-end coverage lives in the na conformance suite, gated on the LLVM shim).
    # The synth is ABI-agnostic here: it declares the param as an int and forwards
    # it verbatim, so make_buf is NEED-linked as the replacement sink.
    res = render_na_source(_OWNING_META, _OWNING_NAME);
    items = {s.item for s in res.skips};
    src = res.source;

    assert "Regex.replace_all" not in items , "replace_all must not be skipped";
    # The callback record address crosses as a plain int; the str result rides the
    # JacBuf out-slot.
    assert "def replace_all(text: str, rep: int) -> str {" in src;
    # The record-address int is forwarded straight to the foreign shim.
    assert "jac_owning_Regex_replace_all(self.__handle, text, strlen(text), rep, out_buf, out_e)" in src;
    # make_buf is declared in the foreign import block (the callback's replacement
    # sink) — only emitted because a bridged method takes a callback.
    assert "def jac_owning_make_buf(s: str, s_len: int, out_buf: int) -> None;" in src;
}
