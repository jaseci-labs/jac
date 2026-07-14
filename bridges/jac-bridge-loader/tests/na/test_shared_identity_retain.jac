# ===========================================================================
# Phase S, Track B (S.4.1 / S.4.3) -- shared / self-identity retain-on-adopt.
# ---------------------------------------------------------------------------
# A method that returns an opaque handle which is NOT a fresh single owner must
# make its adopting wrapper an independent RC owner, or two wrappers over one
# box double-free on their two closes. Two shapes:
#
#   * shared (TAG_SHARED_BIT): one reference on an RC'd inner. The loader retains
#     the returned handle UNCONDITIONALLY on adopt.
#   * self-identity (return type == receiver type): the method may hand back the
#     receiver's OWN box. The loader retains only when `rh == self.__handle`,
#     guarded at runtime, so a fresh-box return (the common case) is untouched.
#
# No producer emits either today (the `#[bridge]` macro boxes every return
# fresh), so this is inert plumbing -- these tests pin the EMITTED na source so
# the retain path is sound the moment Phase 1.2.4 produces such a return. The
# ctypes loader mirrors the same logic at runtime in `_ctypes_codegen._call`.
# ===========================================================================
import from jaclang.compiler.rust_bridge._blob {
    BridgeMeta,
    TypeDesc,
    FnDesc,
    ParamDesc,
    FN_CTOR,
    FN_METHOD,
    KIND_OPAQUE,
    KIND_ERROR,
    TAG_REF_BIT,
    TAG_SHARED_BIT,
    TAG_INT,
    TAG_VOID
}
import from jaclang.compiler.rust_bridge._synth { render_na_source }


def _cell_meta -> BridgeMeta {
    # Cell: a ctor-bearing opaque type with three ref-returning methods --
    #   alias(&self) -> Self          self-identity (returns its own type)
    #   dup(&self)   -> shared Self    shared (TAG_SHARED_BIT on the same type)
    #   peek(&self)  -> Other          plain owned return to a DIFFERENT type
    types = [
        TypeDesc(
            index=0, kind=KIND_OPAQUE, name="Cell", drop_sym="jac_reent_Cell_drop"
        ),
        TypeDesc(
            index=1, kind=KIND_OPAQUE, name="Other", drop_sym="jac_reent_Other_drop"
        ),
        TypeDesc(
            index=2, kind=KIND_ERROR, name="CellError", drop_sym="jac_reent_error_drop"
        )
    ];
    fns = [
        FnDesc(
            index=0,
            name="new",
            sym="jac_reent_Cell_new",
            self_type=TAG_VOID,
            kind=FN_CTOR,
            throws=TAG_VOID,
            ret=TAG_REF_BIT | 0,
            params=[ParamDesc(name="v", tag=TAG_INT)]
        ),
        FnDesc(
            index=1,
            name="alias",
            sym="jac_reent_Cell_alias",
            self_type=0,
            kind=FN_METHOD,
            throws=TAG_VOID,
            ret=TAG_REF_BIT | 0,
            params=[]
        ),
        FnDesc(
            index=2,
            name="dup",
            sym="jac_reent_Cell_dup",
            self_type=0,
            kind=FN_METHOD,
            throws=TAG_VOID,
            ret=TAG_REF_BIT | TAG_SHARED_BIT | 0,
            params=[]
        ),
        FnDesc(
            index=3,
            name="peek",
            sym="jac_reent_Cell_peek",
            self_type=0,
            kind=FN_METHOD,
            throws=TAG_VOID,
            ret=TAG_REF_BIT | 1,
            params=[]
        )
    ];
    return BridgeMeta(abi_version=1, module_name="reent", types=types, fns=fns);
}


def _alias_body(src: str) -> str {
    start = src.find("def alias(");
    end = src.find("    }", src.find("return", start));
    return src[start:end];
}


def _dup_body(src: str) -> str {
    start = src.find("def dup(");
    end = src.find("    }", src.find("return", start));
    return src[start:end];
}


def _peek_body(src: str) -> str {
    start = src.find("def peek(");
    end = src.find("    }", src.find("return", start));
    return src[start:end];
}


test "self-identity return retains only when rh IS the receiver's own box" {
    nm = render_na_source(_cell_meta(), "libjac_bridge_reent.so");
    body = _alias_body(nm.source);

    # The guard fires only for the aliasing case, never for a fresh-box return.
    assert "if rh == self.__handle {" in body;
    assert "jac_reent_Cell_retain(rh);" in body;
    # It is the ctor-bearing self type, so it adopts via the static _adopt path.
    assert "return Cell._adopt(rh);" in body;
}


test "shared return retains the handle unconditionally on adopt" {
    nm = render_na_source(_cell_meta(), "libjac_bridge_reent.so");
    body = _dup_body(nm.source);

    # No runtime guard -- a shared handle is always a co-owned RC reference.
    assert "if rh == self.__handle {" not in body;
    assert "jac_reent_Cell_retain(rh);" in body;
}


test "plain owned return to a different type emits no retain" {
    nm = render_na_source(_cell_meta(), "libjac_bridge_reent.so");
    body = _peek_body(nm.source);

    # peek returns `Other`, a fresh single owner -- unchanged, byte-identical.
    assert "retain" not in body;
    assert "return Other(rh);" in body;
}


test "the per-type retain shim is declared in the import block" {
    nm = render_na_source(_cell_meta(), "libjac_bridge_reent.so");

    # Cell is a shared / self-identity target, so its retain shim is imported.
    assert "def jac_reent_Cell_retain(handle: int) -> None;" in nm.source;
    # Other is only ever a plain owned return, so no retain shim for it.
    assert "jac_reent_Other_retain" not in nm.source;
}
