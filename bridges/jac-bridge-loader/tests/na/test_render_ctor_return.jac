# ===========================================================================
# FFI-LANES Phase 0.5, item 0.5.6 / finding F2 — RED-FIRST PIN
# ---------------------------------------------------------------------------
# BUG (na adopt-ctor signature clash): the na source generator
# `render_na_source` (jaclang.compiler.rust_bridge._synth) drops any METHOD
# that returns an opaque handle whose type ALSO has a constructor. The generated
# wrapper `obj` cannot carry both the real `def init(v)` and the adopt-ctor
# `def init(raw)` at the same arity, so the returning method is refused.
#
# TRIGGER CONDITION (surfaced by `jac-bridge-reentrant`):
#   Cell::alias(&self) -> Self
#   i.e. a FN_METHOD whose return tag is a REF to an opaque type index that is a
#   constructor target (appears in `ctor_targets`). Such a type is deliberately
#   excluded from `self.adoptable`, so the method is refused.
#
# EXACT DROP SITE in jac/jaclang/compiler/rust_bridge/_synth.jac (working tree):
#   * _synth.jac:129-143  — `ctor_targets` / `self.adoptable`: a type produced by
#                           any FN_CTOR is put in ctor_targets and thereby kept
#                           OUT of `adoptable`.
#   * _synth.jac:363-365  — `_method_body`: `elif tag_is_ref(fd.ret) { if
#                           tag_ref_index(fd.ret) not in self.adoptable { return
#                           None; } }` — the ref-return of a ctor-bearing type is
#                           un-bridgeable, so the body is refused.
#   * _synth.jac:507-521  — `render()` classification: the FN_METHOD branch sees
#                           `_method_body(fd) is None`, records a Skip
#                           (reason at :511, "na adopt-ctor signature clash") and
#                           `continue`s — the method never reaches `methods_of`
#                           and so never appears in the emitted na surface.
#   (Same code committed at HEAD:_synth.jac:70-76 / :265 / :407-420.)
#
# CONTRAST — the CPython ctypes loader keeps the method:
#   _ctypes_codegen.jac:450-453 collects EVERY `FN_METHOD` with
#   `self_type == td.index` (only `message` excluded), and :518-519 binds each,
#   with NO adopt-ctor filtering. So `Cell::alias` is callable through the
#   CPython loader but VANISHES on na — the na<->CPython surface-parity loss the
#   plan (0.5.6) documents as "compiles + works through the CPython loader but
#   vanishes on na".
#
# HONESTY STATUS: a parallel Phase-0.5 track already downgraded the *silent*
# drop to a recorded Skip-with-reason (the minimum fix; verified below — the
# method IS present in `nm.skips`). The RESIDUAL, still-red bug this file pins is
# the surface-parity loss: the method must SURVIVE on na (the plan's preferred
# fix — "give the adopt-ctor a distinct arity/name so both survive"). The first
# test asserts survival and is RED today; the eventual _synth.jac fix flips it
# green. The second test is a regression guard on the minimum honesty (drop is
# recorded, never silent).
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
    TAG_INT,
    TAG_STR,
    TAG_VOID
}
import from jaclang.compiler.rust_bridge._synth { render_na_source }


def _reentrant_meta -> BridgeMeta {
    # Minimal mirror of `jac-bridge-reentrant`'s Cell: a ctor-bearing opaque type
    # whose method `alias(&self) -> Self` returns a handle to its OWN
    # (constructor-bearing) type — the adopt-ctor clash trigger.
    types = [
        TypeDesc(
            index=0, kind=KIND_OPAQUE, name="Cell", drop_sym="jac_reent_Cell_drop"
        ),
        TypeDesc(
            index=1, kind=KIND_ERROR, name="CellError", drop_sym="jac_reent_error_drop"
        )
    ];
    fns = [
        # ctor: new(v: i64) -> Cell   (makes Cell a ctor_target)
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
        # plain method: get(&self) -> i64   (bridges fine — the control case)
        FnDesc(
            index=1,
            name="get",
            sym="jac_reent_Cell_get",
            self_type=0,
            kind=FN_METHOD,
            throws=TAG_VOID,
            ret=TAG_INT,
            params=[]
        ),
        # adopt-ctor method: alias(&self) -> Self  (returns ref to ctor-bearing Cell)
        FnDesc(
            index=2,
            name="alias",
            sym="jac_reent_Cell_alias",
            self_type=0,
            kind=FN_METHOD,
            throws=TAG_VOID,
            ret=TAG_REF_BIT | 0,
            params=[]
        ),
        # error message accessor (mirrors real bridges; not part of the surface)
        FnDesc(
            index=3,
            name="message",
            sym="jac_reent_error_message",
            self_type=1,
            kind=FN_METHOD,
            throws=TAG_VOID,
            ret=TAG_STR,
            params=[]
        )
    ];
    return BridgeMeta(abi_version=1, module_name="reent", types=types, fns=fns);
}


test "adopt-ctor method survives on the na surface (parity with CPython loader)" {
    meta = _reentrant_meta();
    nm = render_na_source(meta, "libjac_bridge_reent.so");

    # Sanity: the plain method bridges, proving the fixture is otherwise healthy.
    assert "def get(" in nm.source;

    # The CPython ctypes loader binds `alias` (_ctypes_codegen.jac:450-453,
    # 518-519). The na generator MUST reach the same surface.
    #
    # RED TODAY: `alias` is dropped from the na surface by the adopt-ctor guard
    # in _synth.jac (_method_body ref-return, :363-365 -> classification Skip +
    # continue, :507-521). This assertion FAILS until 0.5.6's preferred fix
    # (distinct-arity adopt-ctor init) lets both the real ctor and the returned
    # wrapper survive.
    assert "def alias(" in nm.source;
}


test "adopt-ctor drop is never silent (minimum-honesty regression guard)" {
    meta = _reentrant_meta();
    nm = render_na_source(meta, "libjac_bridge_reent.so");

    dropped = "def alias(" not in nm.source;
    recorded = any([("alias" in s.item) for s in nm.skips]);

    # If na refuses the adopt-ctor method it must NOT do so silently — it has to
    # leave a recorded Skip. (Currently GREEN: the parallel-track reconcile added
    # the Skip-with-reason. This guard fails if that honesty ever regresses to a
    # silent surface shrink.)
    assert (not dropped) or recorded;
}
