"""`LayoutPass._acyclic_walk` reads a field's type off an undeclared slot.

This file was opened on the theory that the read was dead. The walk reached a
field's type like this:

    var = finfo.decl_node;
    tb = var?.type if var is not None else None;

`decl_node` holds the `HasVar` the field was declared by, and no ancestor of
`HasVar` *declares* `type` -- only `Expr` does. The inference was that
`var?.type` degraded to None for every field, that the loop broke on the
first one, and that `is_acyclic` was therefore False for every layout with
fields, leaving the cycle collector stuck on the conservative answer.

Measured, that is not what happens. `TypeCheckPass.exit_has_var` assigns
`nd.type = declared_type` onto the `HasVar` itself, and `exit_param_var`
does the same for `ParamVar`. Instance attributes are the primary store in
this object model, so the read found a real, deliberately stamped `TypeBase`,
and the walk has been live and discriminating all along -- `Leaf` and `Pair`
below were already acyclic, `SelfRef`, `RingA`, `RingB` and `BoxedRing`
already cyclic. Correcting the walk therefore changes no verdict, and none of
the three things `is_acyclic` gates in `na_ir_gen_pass` move: not
`_emit_trace_fn`'s collector registration, not stack promotion, and not
by-value field inlining. The feared early free was not on the table.

What was real is the undeclared slot. `nd.type = ...` on a node whose class
never declares `type` is the same defect this cluster cleared in
`StaticAnalysisPass._checked_scopes` and wave 5 cleared in
`jsx_intrinsic_guard_pass`: the checker cannot type a read of a slot nobody
declared, which is exactly the two module-level errors `layout_pass` carried
-- `Type "NoneType" has no attribute "mangle"` and the `<Unknown>`
assignment behind it -- and a native lane cannot host the read at all. So
`AstTypedVarNode`, the shared base of `HasVar` and `ParamVar`, declares
`type` now, and the walk narrows to `HasVar` before reading it rather than
reaching through an optional `UniNode`. Both errors clear and the verdicts
are byte-identical.

The tests below pin the behaviour rather than the plumbing, because the
verdicts are what a future change to this walk can break. It stays
conservative everywhere it cannot see: a type the checker never stamped, a
mangled key `_expand_type_keys` cannot round-trip, and a name absent from the
registry all colour 2 ("cyclic"). A back-edge onto a layout still being
walked colours 2 as well, which is what makes the two-step and container
cycles come out right.
"""

import os;
import jaclang.jac0core.unitree as uni;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "main", "fixtures", "layout_acyclicity.jac"
     ),
     _REG_MEMO: list = [];

"""The fixture's layout registry, built once through the real pass."""
def _registry -> any {
    if _REG_MEMO {
        return _REG_MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE, options=CompileOptions(aot_mode=True, type_check=True)
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    reg = get_layout_registry(ir, prog);
    _REG_MEMO.append(reg);
    return reg;
}

"""Whether the walk called a layout acyclic. Asserts the layout exists."""
def _acyclic(name: str) -> bool {
    lay = _registry().get_layout(name);
    assert lay is not None , (
        f"no layout for {name}; the fixture stopped producing one, so this "
        "file would be asserting about nothing"
    );
    return lay.is_acyclic;
}


"""Whether a node type declares a has-field of the given name, anywhere in its MRO.

The slot is a per-instance field, so it is absent from the class itself; the
declaration shows up in `__annotations__` of whichever ancestor declares it.
"""
def _declares(node_type: type, field: str) -> bool {
    for cls in node_type.__mro__ {
        if field in getattr(cls, '__annotations__', {}) {
            return True;
        }
    }
    return False;
}


test "the slot the type checker stamps on a typed var is a declared one" {
    # This is the fix, stated as a fact: the checker writes `.type` onto
    # HasVar and ParamVar, so the class has to declare it. Undeclared, the
    # read type-checks as NoneType and no native lane can host it.
    assert _declares(uni.HasVar, 'type') , (
        "HasVar lost its declared 'type' slot, but TypeCheckPass.exit_has_var "
        "still assigns it -- that is an undeclared stash, and it is what put "
        "two checker errors in layout_pass"
    );
    assert _declares(uni.ParamVar, 'type') , (
        "ParamVar lost its declared 'type' slot; exit_param_var stamps it the "
        "same way exit_has_var does"
    );
    assert _declares(uni.HasVar, 'type_tag') , (
        "HasVar lost type_tag, which is where its declared type expression "
        "lives and how the layout pass reaches the annotation node"
    );
}


test "a layout of scalars and acyclic archetypes is classified acyclic" {
    # This is the half that was dead: every one of these came out False
    # while the walk was reading a slot that does not exist.
    assert _acyclic("Leaf") , (
        "Leaf holds an int and a str and reaches nothing; if it is cyclic "
        "the walk is failing to resolve a field type again"
    );
    assert _acyclic("Pair") , (
        "Pair holds two Leafs and a float, so it is acyclic exactly when "
        "Leaf is -- a False here with Leaf True means the recursion, not "
        "the field read, is losing the answer"
    );
}


test "every genuinely cyclic layout is still classified cyclic" {
    # The dangerous direction. `is_acyclic` suppresses the trace function,
    # permits stack promotion and permits by-value field inlining, so a
    # false acyclic here is a real memory bug, not a missed optimisation.
    assert not _acyclic("SelfRef") , (
        "SelfRef holds `(SelfRef | None)`; the walk must colour the "
        "back-edge onto the layout it is still walking as cyclic"
    );
    assert not _acyclic("RingA") , "RingA -> RingB -> RingA is a cycle";
    assert not _acyclic("RingB") , "RingB -> RingA -> RingB is a cycle";
    assert not _acyclic("BoxedRing") , (
        "BoxedRing holds `list[BoxedRing]`; a cycle through a container "
        "element is still a cycle, and _expand_type_keys has to carry the "
        "element type through for the walk to see it"
    );
}


test "a field the walk cannot resolve keeps the conservative answer" {
    # Every `has` field in Jac carries a type tag, so the walk's "no tag"
    # branch is unreachable from source; what is reachable is a tag whose
    # mangled key names nothing the registry knows. `any` is that case, and
    # it has to stay cyclic -- an acyclic verdict for a field that could
    # hold anything would permit inlining and stack promotion on a value
    # whose shape is not known at all.
    assert not _acyclic("Opaque") , (
        "Opaque holds an `any`, so the walk cannot know what it reaches and "
        "must keep answering cyclic. An acyclic verdict here means the walk "
        "started guessing"
    );
}
