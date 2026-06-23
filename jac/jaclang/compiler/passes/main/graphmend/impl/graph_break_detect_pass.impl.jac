"""GraphMend graph-break detection pass implementation."""

"""Gate the pass on the --graphmend flag and presence of an entry point."""
impl GraphBreakDetectPass.before_pass -> None {
    self._enabled = getattr(self.prog._compile_options, 'graphmend', False);
    if not self._enabled {
        self.prune_signal = True;
        return;
    }
    # A module imported under --graphmend-scope is user-declared model code:
    # treat its entire body as a compiled region (no local entry needed).
    self._whole_module = getattr(self.prog, '_graphmend_scoped_compile', False);
    if self._whole_module {
        return;
    }
    self._entry_ids = self._collect_entry_points();
    if not self._entry_ids {
        self._enabled = False;
        self.prune_signal = True;
    }
}

"""Tag data-dependent if/elif/else and validation-guard conditionals.

Every condition in an if/elif chain can independently be a graph break (the
leading `if` may be static while a downstream `elif` is data-dependent), so the
whole chain -- reached through `else_body` -- is walked from the leading `if`.
The node-typed walker dispatches this hook only for the leading `if`; an `elif`
is an ElseIf node, so it is reached here through the chain, never on its own."""
impl GraphBreakDetectPass.enter_if_stmt(nd: uni.IfStmt) -> None {
    if not self._enabled {
        return;
    }
    if not self._in_torch_compiled_scope(nd) {
        return;
    }
    cur: (uni.IfStmt | None) = nd;
    while cur is not None {
        if self._condition_is_data_dependent(cur.condition) {
            if self._is_validation_guard(cur) {
                cur._gm_break_kind = BreakKind.VAL_GUARD;
            } elif not self._body_ends_in_raise(cur) {
                cur._gm_break_kind = BreakKind.DYN_CTRL_FL;
            }
            # A raise-terminated branch that is not a standalone guard (an
            # `elif`, or one paired with an `else`) cannot be lowered by either
            # transform without changing semantics -- an assert would fire
            # unconditionally and the value-predicating rewrite would drop the
            # raise -- so it is left untagged: a correct, unoptimized break.
        }
        nxt = cur.else_body;
        if isinstance(nxt, uni.ElseIf) {
            cur = nxt;
        } else {
            cur = None;
        }
    }
}

"""Tag print / logger side-effect calls."""
impl GraphBreakDetectPass.enter_func_call(nd: uni.FuncCall) -> None {
    if not self._enabled {
        return;
    }
    if not self._in_torch_compiled_scope(nd) {
        return;
    }
    name = self._call_name(nd);
    if (name is None) or (not is_side_effect_name(name)) {
        return;
    }
    # The shadowing check applies only to a bare builtin call (e.g. a
    # user-redefined `print`). For `logger.info(...)` the matched name is the
    # method, not a module symbol, so looking it up would wrongly suppress the
    # break whenever an unrelated module-level `def info(...)` exists.
    if isinstance(nd.target, uni.Name) and self._is_user_defined(nd, name) {
        return;
    }
    nd._gm_break_kind = BreakKind.SIDE_EFFECT;
}

"""Collect torch.compile entry points: functions/classes decorated with
@torch.compile, or wrapped at a call site -- torch.compile(fn) /
torch.compile(Model()) / `m = Model(); torch.compile(m)`."""
impl GraphBreakDetectPass._collect_entry_points -> set[int] {
    ids: set[int] = set();
    for ab in UniPass.get_all_sub_nodes(self.ir_in, uni.Ability) {
        if self._has_torch_compile_decorator(ab) {
            ids.add(id(ab));
        }
    }
    for arch in UniPass.get_all_sub_nodes(self.ir_in, uni.Archetype) {
        if self._has_torch_compile_decorator(arch) {
            ids.add(id(arch));
        }
    }
    for call in UniPass.get_all_sub_nodes(self.ir_in, uni.FuncCall) {
        if self._call_is_torch_compile(call) {
            entry = self._resolve_wrapped_entry(call);
            if entry is not None {
                ids.add(id(entry));
            }
        }
    }
    return ids;
}

"""True if `call` is a torch.compile(...) invocation (structural)."""
impl GraphBreakDetectPass._call_is_torch_compile(call: uni.FuncCall) -> bool {
    t = call.target;
    return (
        isinstance(t, uni.AtomTrailer)
        and isinstance(t.right, uni.Name)
        and (t.right.value == 'compile')
        and isinstance(t.target, uni.Name)
        and (t.target.value == 'torch')
    );
}

"""Resolve the function/class wrapped by torch.compile(...) to its defining
Ability/Archetype in this module, else None.

The wrapped object is torch.compile's first parameter, `model`, passed either
positionally (`torch.compile(m)`) or by keyword (`torch.compile(model=m)`)."""
impl GraphBreakDetectPass._resolve_wrapped_entry(
    call: uni.FuncCall
) -> (uni.UniNode | None) {
    arg = None;
    kw_model = None;
    for p in (call.params or []) {
        if isinstance(p, uni.KWPair) {
            if isinstance(p.key, uni.Name) and (p.key.value == 'model') {
                kw_model = p.value;
            }
        } elif arg is None {
            arg = p;
        }
    }
    if arg is None {
        arg = kw_model;
    }
    if arg is None {
        return None;
    }
    if isinstance(arg, uni.FuncCall) {
        # torch.compile(Model()) compiles the instance, so its CLASS is the entry.
        # torch.compile(make_model()) compiles the factory's RETURN value (not
        # statically resolvable); the factory body runs outside any compiled
        # region, so a callee that resolves to a function is NOT an entry.
        target = arg.target;
        if isinstance(target, uni.Name) {
            resolved = self._def_node(target.value, call);
            if isinstance(resolved, uni.Archetype) {
                return resolved;
            }
        }
        return None;
    }
    if not isinstance(arg, uni.Name) {
        return None;
    }
    # direct: torch.compile(fn) / torch.compile(Class)
    resolved = self._def_node(arg.value, call);
    if resolved is not None {
        return resolved;
    }
    # variable: torch.compile(m) where `m = Model(...)` -- only a class
    # instantiation is an entry (a factory `m = make_model()` is not).
    assign = self._var_assignment(arg.value, call);
    if (assign is not None) and isinstance(assign.value, uni.FuncCall) {
        ctor = assign.value.target;
        if isinstance(ctor, uni.Name) {
            cls = self._def_node(ctor.value, call);
            if isinstance(cls, uni.Archetype) {
                return cls;
            }
        }
    }
    return None;
}

"""Return the Ability/Archetype declared as `name` in scope, else None.

Only the name's own definition site counts: the def node itself or its name ref
(immediate parent). We do NOT walk further up the parent chain -- a parameter or
local variable would otherwise resolve to its ENCLOSING function, wrongly marking
that whole function as a torch.compile entry (e.g. `torch.compile(model)` where
`model` is a parameter)."""
impl GraphBreakDetectPass._def_node(
    name: str, ctx: uni.UniNode
) -> (uni.UniNode | None) {
    st = ctx.sym_tab;
    if not st {
        return None;
    }
    sym = st.lookup(name, deep=True);
    if (not sym) or (not sym.defn) {
        return None;
    }
    d = sym.defn[0];
    if isinstance(d, (uni.Ability, uni.Archetype)) {
        return d;
    }
    if isinstance(d.parent, (uni.Ability, uni.Archetype)) {
        return d.parent;
    }
    return None;
}

"""Return the Assignment defining variable `name` in scope, else None."""
impl GraphBreakDetectPass._var_assignment(
    name: str, ctx: uni.UniNode
) -> (uni.Assignment | None) {
    st = ctx.sym_tab;
    if not st {
        return None;
    }
    sym = st.lookup(name, deep=True);
    if not sym {
        return None;
    }
    return self._defining_assignment(sym);
}

"""True if `nd` is decorated with torch.compile (with or without args).

Matched structurally, not via unparse() text -- .py and .jac ASTs render the
decorator differently, so a text match silently fails on .py models.
"""
impl GraphBreakDetectPass._has_torch_compile_decorator(nd: uni.UniNode) -> bool {
    decs = nd?.decorators;
    for dec in (decs or []) {
        target = dec.target if isinstance(dec, uni.FuncCall) else dec;
        if (
            isinstance(target, uni.AtomTrailer)
            and isinstance(target.right, uni.Name)
            and (target.right.value == 'compile')
            and isinstance(target.target, uni.Name)
            and (target.target.value == 'torch')
        ) {
            return True;
        }
    }
    return False;
}

"""True if `nd` lives inside a torch.compile entry point (decorated or wrapped at
a call site), or anywhere in a --graphmend-scope'd module."""
impl GraphBreakDetectPass._in_torch_compiled_scope(nd: uni.UniNode) -> bool {
    if self._whole_module {
        return True;
    }
    cur = nd.parent;
    while cur {
        if id(cur) in self._entry_ids {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

"""Get the callee name of a FuncCall (bare name or trailing attribute)."""
impl GraphBreakDetectPass._call_name(nd: uni.FuncCall) -> (str | None) {
    target = nd.target;
    if isinstance(target, uni.Name) {
        return target.value;
    }
    if (isinstance(target, uni.AtomTrailer) and isinstance(target.right, uni.Name)) {
        return target.right.value;
    }
    return None;
}

"""True if `name` resolves to a user-defined symbol (shadowed builtin)."""
impl GraphBreakDetectPass._is_user_defined(nd: uni.FuncCall, name: str) -> bool {
    st = nd.sym_tab;
    if not st {
        return False;
    }
    sym = st.lookup(name, deep=True);
    return bool(sym and sym.defn);
}

"""True if `nd` is a validation guard: a STANDALONE one-armed conditional (no
else, not an `elif`) whose body ends in a `raise`, e.g. `if not C: raise` or
`if not C: cleanup(); raise`.

An `elif ...: raise` is deliberately excluded: its raise is conditional on the
preceding branches being false, so lowering it as a standalone
`torch._assert_async(not C)` would fire unconditionally. Keying on the trailing
raise (not a single-statement body) keeps a guard with cleanup code classified as
`val_guard` rather than `dyn_ctrl_fl`, so it is never handed to the
value-predicating rewrite that would drop the cleanup."""
impl GraphBreakDetectPass._is_validation_guard(nd: uni.IfStmt) -> bool {
    if isinstance(nd, uni.ElseIf) {
        return False;
    }
    if nd.else_body is not None {
        return False;
    }
    return self._body_ends_in_raise(nd);
}

"""True if `nd`'s body ends in a `raise` statement."""
impl GraphBreakDetectPass._body_ends_in_raise(nd: uni.IfStmt) -> bool {
    return bool(nd.body) and isinstance(nd.body[-1], uni.RaiseStmt);
}

"""True if `cond` is data-dependent: uses a dynamic torch attr, or a use-def
trace over the symbol table reaches one."""
impl GraphBreakDetectPass._condition_is_data_dependent(cond: uni.Expr) -> bool {
    if self._expr_uses_dynamic_attr(cond) {
        return True;
    }
    st = cond.sym_tab;
    if not st {
        return False;
    }
    visited: set[int] = set();
    for nm in cond.get_all_sub_nodes(uni.Name) {
        sym = st.lookup(nm.value, deep=True);
        if sym and self._trace_symbol(sym, visited, 0) {
            return True;
        }
    }
    return False;
}

"""True if any attribute trailer in `expr` names a dynamic torch op.

This keys on the attribute name (`x.sum()`, `x.item()`), not the receiver's
type -- distinguishing a tensor `x.sum()` from a non-tensor `df.sum()` would
require type inference that is not reliably available here. The match is
therefore intentionally permissive (it catches the paper's `x.sum()` on a
tensor parameter, which no name-blind type check could). Over-tagging is safe:
each transformation pass independently re-checks legality (tensor-valued
branches, etc.) and declines to rewrite anything it cannot prove safe."""
impl GraphBreakDetectPass._expr_uses_dynamic_attr(expr: uni.Expr) -> bool {
    for tr in expr.get_all_sub_nodes(uni.AtomTrailer) {
        if tr.is_attr and isinstance(tr.right, uni.Name) {
            if is_dynamic_torch_attr(tr.right.value) {
                return True;
            }
        }
    }
    return False;
}

"""True if `sym` derives (directly or transitively) from a dynamic torch attr,
e.g. `seq_len = torch.max(position_ids) + 1`.

Parameters are deliberately NOT treated as dynamic -- that would misfire on
object params (e.g. tagging `if hasattr(self, ...)` as data-dependent).
"""
impl GraphBreakDetectPass._trace_symbol(
    sym: uni.Symbol, visited: set[int], depth: int
) -> bool {
    if (depth > 10) or (id(sym) in visited) {
        return False;
    }
    visited.add(id(sym));
    for assign in self._defining_assignments(sym) {
        if assign.value is None {
            continue;
        }
        if self._expr_uses_dynamic_attr(assign.value) {
            return True;
        }
        st = assign.sym_tab;
        if not st {
            continue;
        }
        for nm in assign.value.get_all_sub_nodes(uni.Name) {
            dep = st.lookup(nm.value, deep=True);
            if dep and (id(dep) not in visited) {
                if self._trace_symbol(dep, visited, depth + 1) {
                    return True;
                }
            }
        }
    }
    return False;
}

"""Every Assignment that defines `sym`. A variable may be assigned on multiple
paths (e.g. both arms of an if/else); checking all of them avoids missing a
dynamic origin reachable on only one branch."""
impl GraphBreakDetectPass._defining_assignments(
    sym: uni.Symbol
) -> list[uni.Assignment] {
    out = [];
    seen: set[int] = set();
    for d in (sym.defn or []) {
        cur = d.parent;
        while cur and (not isinstance(cur, uni.Assignment)) {
            cur = cur.parent;
        }
        if isinstance(cur, uni.Assignment) and (id(cur) not in seen) {
            seen.add(id(cur));
            out.append(cur);
        }
    }
    return out;
}

"""Return the last Assignment that defines `sym`, if any."""
impl GraphBreakDetectPass._defining_assignment(
    sym: uni.Symbol
) -> (uni.Assignment | None) {
    if not sym.defn {
        return None;
    }
    cur = sym.defn[-1].parent;
    while cur and (not isinstance(cur, uni.Assignment)) {
        cur = cur.parent;
    }
    if isinstance(cur, uni.Assignment) {
        return cur;
    }
    return None;
}
