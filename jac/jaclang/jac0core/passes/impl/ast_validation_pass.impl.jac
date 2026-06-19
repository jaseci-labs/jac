"""Implementation for AST validation pass.

Checks moved here from the parser to follow the modern compiler pattern of
'parse permissively, validate later'. Each enter_* visitor validates a specific
structural invariant on the already-constructed AST node.

Uses the structured diagnostic code system (self.emit) for precise, machine-
readable error reporting with suppression support.
"""
"""Validate match statement has at least one case."""
impl ASTValidationPass.enter_match_stmt(
    self: ASTValidationPass, nd: uni.MatchStmt
) -> None {
    if len(nd.cases) == 0 {
        self.emit(E0041, node_override=nd);
    }
}

"""Validate module-level 'with' blocks only use 'entry', not 'exit'."""
impl ASTValidationPass.enter_module_code(
    self: ASTValidationPass, nd: uni.ModuleCode
) -> None {
    # ModuleCode stores entry/exit token in kid list. Check if any kid
    # token has KW_EXIT name, indicating 'with exit { ... }' at module level.
    # Only flag this when the ModuleCode is directly under a Module (top-level).
    if isinstance(nd.parent, uni.Module) or nd.parent is None {
        for k in nd.kid {
            if isinstance(k, uni.Token) and k.name == Tok.KW_EXIT {
                self.emit(E0031, node_override=nd);
                break;
            }
        }
    }
}

"""Validate walrus operator has a simple name on the left side."""
impl ASTValidationPass.enter_binary_expr(
    self: ASTValidationPass, nd: uni.BinaryExpr
) -> None {
    if nd.op is not None
    and isinstance(nd.op, uni.Token)
    and nd.op.name == Tok.WALRUS_EQ {
        if not isinstance(nd.left, uni.Name)
        and not isinstance(nd.left, uni.SpecialVarRef) {
            self.emit(E0020, node_override=nd.left);
        }
    }
}

"""Validate 'pass' is not used as an identifier.

`new` was historically rejected here, but is now an ambient builtin
(`new(Cls, ...args)`) supplied by `jaclang.runtimelib.builtin`. The
ambient builtin lowers to `Cls(*args)` on the server and to
`Reflect.construct(Cls, [args])` in `cl` blocks, so it is a legitimate
identifier in every codespace. The historical JS-keyword form
`new Foo()` is still rejected by the parser as a syntax error.
"""
impl ASTValidationPass.enter_name(self: ASTValidationPass, nd: uni.Name) -> None {
    if nd.value == "pass" {
        self.emit(E0010, node_override=nd, keyword="pass");
    }
}

"""E0052: function/method parameters must have type annotations."""
impl ASTValidationPass.enter_param_var(
    self: ASTValidationPass, nd: uni.ParamVar
) -> None {
    # Skip lambda parameters — lambdas allow type inference.
    sig = nd.parent;
    if isinstance(sig, uni.FuncSignature) and isinstance(sig.parent, uni.LambdaExpr) {
        return;
    }
    if nd.type_tag is None {
        param_name = nd.name.value if isinstance(nd.name, uni.Name) else str(nd.name);
        self.emit(E0052, node_override=nd, name=param_name);
    }
}

"""Validate parameter ordering: /, *, ** must be in correct positions."""
impl ASTValidationPass.enter_func_signature(
    self: ASTValidationPass, nd: uni.FuncSignature
) -> None {
    has_slash = False;
    has_star = False;
    has_kwargs = False;
    for k in nd.kid {
        if isinstance(k, uni.Token) and k.name == Tok.DIV {
            if has_slash {
                self.emit(E0050, node_override=k, param="/");
            } elif has_star {
                self.emit(E0051, node_override=k, first="/", second="*");
            } elif has_kwargs {
                self.emit(E0051, node_override=k, first="/", second="**kwargs");
            }
            has_slash = True;
        } elif isinstance(k, uni.Token) and k.name == Tok.STAR_MUL {
            if has_star {
                self.emit(E0050, node_override=k, param="*");
            } elif has_kwargs {
                self.emit(E0051, node_override=k, first="*", second="**kwargs");
            }
            has_star = True;
        } elif isinstance(k, uni.ParamVar) {
            if k.unpack and k.unpack?.name {
                if k.unpack.name == Tok.STAR_MUL {
                    if has_star {
                        self.emit(E0050, node_override=k, param="*");
                    } elif has_kwargs {
                        self.emit(E0051, node_override=k, first="*", second="**kwargs");
                    }
                    has_star = True;
                } elif k.unpack.name == Tok.STAR_POW {
                    if has_kwargs {
                        self.emit(E0050, node_override=k, param="**kwargs");
                    }
                    has_kwargs = True;
                }
            }
        }
    }
}

"""Validate for...to...by step has augmented assignment."""
impl ASTValidationPass.enter_iter_for_stmt(
    self: ASTValidationPass, nd: uni.IterForStmt
) -> None {
    # IterForStmt.count_by is the step assignment. If it has no aug_op,
    # it wasn't an augmented assignment (+=, -=, etc.)
    if nd.count_by is not None
    and isinstance(nd.count_by, uni.Assignment)
    and nd.count_by.aug_op is None {
        self.emit(E0023, node_override=nd.count_by);
    }
}

"""Validate enum body has at least one member."""
impl ASTValidationPass.enter_enum(self: ASTValidationPass, nd: uni.Enum) -> None {
    if nd.body is not None and len(nd.body) == 0 {
        self.emit(E0043, node_override=nd);
    }
}

"""Validate switch statement has at least one case."""
impl ASTValidationPass.enter_switch_stmt(
    self: ASTValidationPass, nd: uni.SwitchStmt
) -> None {
    if len(nd.cases) == 0 {
        self.emit(E0042, node_override=nd);
    }
}

"""Validate assignment targets are not non-assignable built-in references."""
impl ASTValidationPass.enter_assignment(
    self: ASTValidationPass, nd: uni.Assignment
) -> None {
    # root and super compile to function calls (e.g. Jac.root()) which
    # cannot appear on the left side of an assignment in Python.
    non_assignable = {Tok.KW_ROOT, Tok.KW_SUPER};
    for target in nd.target {
        ref_node: (uni.SpecialVarRef | None) = None;
        if isinstance(target, uni.SpecialVarRef) {
            ref_node = target;
        } elif isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.SpecialVarRef) {
            ref_node = target.right;
        }
        if ref_node is not None and ref_node.name in non_assignable {
            self.emit(E0024, node_override=ref_node, name=ref_node.value);
        }
    }
}

"""Validate import statement has at least one item."""
impl ASTValidationPass.enter_import(self: ASTValidationPass, nd: uni.Import) -> None {
    if nd.items is not None
    and len(nd.items) == 0
    and (nd.clib_decls is None or len(nd.clib_decls) == 0) {
        self.emit(E0044, node_override=nd);
    }
}

"""E0055: yield is only valid inside a function body."""
impl ASTValidationPass.enter_yield_expr(
    self: ASTValidationPass, nd: uni.YieldExpr
) -> None {
    if nd.find_parent_of_type(uni.Ability) is None
    and nd.find_parent_of_type(uni.ImplDef) is None {
        self.emit(E0055, node_override=nd);
    }
}

"""E0058: break/continue are only valid inside a loop."""
impl ASTValidationPass.enter_ctrl_stmt(
    self: ASTValidationPass, nd: uni.CtrlStmt
) -> None {
    if nd.ctrl is None or not isinstance(nd.ctrl, uni.Token) {
        return;
    }
    kw = nd.ctrl.value;
    if kw not in ("break", "continue") {
        return;
    }
    # Walk parents looking for a loop (or switch for break)
    parent = nd.parent;
    while parent is not None {
        if isinstance(parent, (uni.InForStmt, uni.IterForStmt, uni.WhileStmt)) {
            return;
        }
        # break is also valid inside switch/match statements
        if kw == "break" and isinstance(parent, (uni.SwitchStmt, uni.MatchStmt)) {
            return;
        }
        # Stop at function/ability/impl boundary — loop must be in same function
        if isinstance(parent, (uni.Ability, uni.ImplDef, uni.Module)) {
            break;
        }
        parent = parent.parent;
    }
    self.emit(E0058, node_override=nd, keyword=kw);
}

"""E0062: nonlocal is not valid at module level."""
impl ASTValidationPass.enter_non_local_stmt(
    self: ASTValidationPass, nd: uni.NonLocalStmt
) -> None {
    # nonlocal should be inside a function, not at module/entry level
    if nd.find_parent_of_type(uni.Ability) is None
    and nd.find_parent_of_type(uni.ImplDef) is None {
        self.emit(E0062, node_override=nd);
    }
}

"""E0063: glob is only valid at module level."""
impl ASTValidationPass.enter_global_vars(
    self: ASTValidationPass, nd: uni.GlobalVars
) -> None {
    # glob is a declaration: it is valid directly under the module or a
    # codespace block (cl/sv/na), but never inside a function body, impl,
    # archetype, or an executable code block ('with entry', loops, test, etc.).
    # Whitelisting valid parents rejects unknown containers by default, which
    # is safer than blacklisting (a new executable block type can't slip glob
    # through).
    valid_parents = (uni.Module, uni.ClientBlock, uni.ServerBlock, uni.NativeBlock);
    if not isinstance(nd.parent, valid_parents) {
        self.emit(E0063, node_override=nd);
    }
}

"""E0065/E0066: duplicate keyword args and positional after keyword args.
E0071: bare except not last.
E0075: duplicate base classes."""
impl ASTValidationPass.enter_func_call(
    self: ASTValidationPass, nd: uni.FuncCall
) -> None {
    if nd.params is None {
        return;
    }
    seen_kw = False;
    seen_kw_names: set[str] = set();
    for param in nd.params {
        if isinstance(param, uni.KWPair) {
            seen_kw = True;
            if param.key is not None {
                kw_name = param.key.value
                    if isinstance(param.key, uni.Name)
                    else str(param.key);
                if kw_name in seen_kw_names {
                    self.emit(E0065, node_override=param, name=kw_name);
                }
                seen_kw_names.add(kw_name);
            }
        } else {
            # Positional argument
            if seen_kw {
                self.emit(E0066, node_override=param);
            }
        }
    }
}

"""E0071: bare except must be last. E0075: duplicate base class. E0076: duplicate method."""
impl ASTValidationPass.enter_archetype(
    self: ASTValidationPass, nd: uni.Archetype
) -> None {
    # E0075: duplicate base class
    if nd.base_classes is not None {
        seen_bases: set[str] = set();
        for base in nd.base_classes {
            base_name: str | None = None;
            if isinstance(base, uni.Name) {
                base_name = base.value;
            } elif isinstance(base, uni.AtomTrailer)
            and isinstance(base.right, uni.Name) {
                base_name = base.right.value;
            }
            if base_name is not None {
                if base_name in seen_bases {
                    self.emit(E0075, node_override=base, name=base_name);
                }
                seen_bases.add(base_name);
            }
        }
    }
    # E0076: duplicate method definition
    body: list = [];
    if isinstance(nd.body, (list, tuple)) {
        body = list(nd.body);
    } elif isinstance(nd.body, uni.ImplDef)
    and isinstance(nd.body.body, (list, tuple)) {
        body = list(nd.body.body);
    }
    # Phase 1: collect names declared with `@property` in this class body.
    # Property-accessor decorators (`@<name>.setter` / `.getter` / `.deleter`)
    # reuse the same method name to extend the property, so a method whose
    # decorator matches `@<name>.<accessor>` is only a "property accessor"
    # (and not a duplicate-method error) when `<name>` is actually a property
    # declared in this class. Limiting the skip to that case preserves real
    # duplicate detection in patterns like `@bar.setter def foo` (where `bar`
    # is not a property — the second `def foo` should still collide with
    # any earlier `def foo` in the class).
    properties_seen: set[str] = set();
    for item in body {
        if (
            isinstance(item, uni.Ability)
            and item.name_ref is not None
            and item.decorators is not None
        ) {
            for dec in item.decorators {
                if isinstance(dec, uni.Name) and dec.value == "property" {
                    properties_seen.add(item.name_ref.value);
                    break;
                }
            }
        }
    }

    # Phase 2: duplicate detection with property-accessor awareness.
    # `seen_methods` tracks plain method names; `seen_accessors` tracks
    # `(property_name, accessor_kind)` so that two `@x.setter def x` defs
    # still flag as a duplicate accessor.
    seen_methods: set[str] = set();
    seen_accessors: set[tuple[(str, str)]] = set();
    for item in body {
        if not (isinstance(item, uni.Ability) and item.name_ref is not None) {
            continue;
        }
        has_overload = False;
        accessor_kind: (str | None) = None;
        accessor_target: (str | None) = None;
        if item.decorators is not None {
            for dec in item.decorators {
                if isinstance(dec, uni.Name) and dec.value == "overload" {
                    has_overload = True;
                } elif (
                    isinstance(dec, uni.AtomTrailer)
                    and isinstance(dec.right, uni.Name)
                    and dec.right.value in ("setter", "getter", "deleter")
                    and isinstance(dec.target, uni.Name)
                ) {
                    accessor_kind = dec.right.value;
                    accessor_target = dec.target.value;
                }
            }
        }
        # @overload-decorated methods may legitimately repeat names.
        if has_overload {
            continue;
        }
        mname = item.name_ref.value;
        # Dedup on the emitted Python identity, not the surface value. The
        # constructor (Jac `def init`, or a Python `__init__` raised by
        # PyastBuildPass) carries the KW_INIT token and emits as `__init__`,
        # while a plain Python method named `init` is an ordinary NAME token
        # emitting as `init` -- both have value 'init' but are distinct
        # methods (PyastGenPass._py_name makes the same token-kind
        # distinction). Keying on the value alone rejected valid Python
        # classes like Pillow's PIL.ImageFile.PyCodec.
        dedup_name = '__init__' if item.name_ref.name == Tok.KW_INIT else mname;
        # Recognise a property accessor only when the decorator's target Name
        # matches the method name and that name was declared `@property` in
        # this class. The first guard rejects cross-property accessors like
        # `@bar.setter def foo`; the second rejects accessors for properties
        # not declared here. Both cases fall through to plain dup detection,
        # which is what catches real bugs that a looser structural check
        # would silently swallow.
        if (
            accessor_kind is not None
            and accessor_target == mname
            and mname in properties_seen
        ) {
            key = (mname, accessor_kind);
            if key in seen_accessors {
                # Two `@x.setter def x` (or two `.getter` / `.deleter`):
                # a genuine duplicate accessor — flag it.
                self.emit(E0076, node_override=item.name_ref, name=mname);
            }
            seen_accessors.add(key);
            continue;
        }
        if dedup_name in seen_methods {
            self.emit(E0076, node_override=item.name_ref, name=mname);
        }
        seen_methods.add(dedup_name);
    }
}

"""E0071: validate bare except is the last except clause."""
impl ASTValidationPass.enter_try_stmt(
    self: ASTValidationPass, nd: uni.TryStmt
) -> None {
    # `awaiting` counts as a clause for the "non-empty try" rule — a
    # `try { ... } awaiting { ... }` is a complete construct on its own
    # (the resolved value's exceptions just propagate to the enclosing
    # ErrorBoundary).
    if len(nd.excepts) == 0 and nd.finally_body is None and nd.awaiting_body is None {
        self.emit(E0040, node_override=nd);
    }
    # E0071: bare except must be last
    for (i, exc) in enumerate(nd.excepts) {
        if exc.ex_type is None and i < len(nd.excepts) - 1 {
            self.emit(E0071, node_override=exc);
        }
    }
}

# ----- JSX `{...}` slot body rules ------------------------------------------
"""Validate a JSX statement-form slot body.

The slot body is a statement template that the cl-target codegen lowers
into an accumulator IIFE. These rules are codegen-independent (they hold
for every target), so they live here, on the faithful surface AST,
rather than in the cl lowering. Nested slots are validated by their own
`enter_jsx_slot`, so this walks only the immediate body (recursing
through control flow, not into nested JSX children)."""
impl ASTValidationPass.enter_jsx_slot(
    self: ASTValidationPass, nd: uni.JsxSlot
) -> None {
    self._check_slot_body([s for s in nd.body], False, "");
}

impl ASTValidationPass._check_slot_body(
    self: ASTValidationPass, stmts: list, in_loop: bool, loop_kw: str
) -> None {
    for s in stmts {
        if isinstance(s, uni.ReturnStmt) {
            # Any `return` in a slot body is forbidden: a slot body is an
            # inlined IIFE, so `return;` reads like a function-exit but only
            # exits the slot. `skip;` is the canonical slot early-exit;
            # `return expr;` makes no sense since slots render template
            # content.
            if s.expr is not None {
                self.emit(E2019, node_override=s);
            } else {
                self.emit(E2020, node_override=s);
            }
        } elif isinstance(s, uni.CtrlStmt) {
            # `skip;` is the slot early-exit — always allowed, including
            # inside slot loops. Only `break;` remains ambiguous in a slot
            # loop (exit-loop vs. exit-slot).
            if in_loop and s.ctrl.value == "break" {
                self.emit(E2021, node_override=s, kw=s.ctrl.value, loop=loop_kw);
            }
        } elif isinstance(s, uni.ArchHas) {
            # `has`-fields inside a slot body would compile to a conditional
            # `useState` — a rules-of-hooks violation. State belongs at the
            # enclosing `def -> JsxElement` scope.
            self.emit(E2024, node_override=s);
        } elif isinstance(s, uni.WhileStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                self.emit(W2019, node_override=s);
            }
            self._check_slot_body([b for b in s.body], True, "while");
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, uni.InForStmt) or isinstance(s, uni.IterForStmt) {
            # Keyless for-loop in a slot: an unkeyed loop child contributes
            # its JSX as flat siblings, so a re-render with a reordered
            # iterable loses iteration identity. W2021 names the fix.
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                self.emit(W2021, node_override=s);
            }
            self._check_slot_body([b for b in s.body], True, "for");
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, uni.IfStmt) {
            # IfStmt also matches ElseIf (a subclass).
            self._check_slot_body([b for b in s.body], in_loop, loop_kw);
            self._check_slot_else(s.else_body, in_loop, loop_kw);
        } elif isinstance(s, uni.WithStmt) {
            self._check_slot_body([b for b in s.body], in_loop, loop_kw);
        } elif isinstance(s, uni.TryStmt) {
            # `awaiting`-specific rules (these used to live in the cl
            # lowering): `finally` is incompatible with `awaiting`, and
            # `awaiting` only lowers on the cl target today.
            if s.awaiting_body is not None {
                if s.finally_body is not None {
                    self.emit(E2022, node_override=s);
                }
                if not s.in_client_context() {
                    target = "na" if s.in_native_context() else "sv";
                    self.emit(W2020, node_override=s, target=target);
                }
            }
            self._check_slot_body([b for b in s.body], in_loop, loop_kw);
            if s.awaiting_body is not None {
                self._check_slot_body(
                    [b for b in s.awaiting_body.body], in_loop, loop_kw
                );
            }
            for ex in s.excepts {
                self._check_slot_body([b for b in ex.body], in_loop, loop_kw);
            }
            self._check_slot_else(s.else_body, in_loop, loop_kw);
            if s.finally_body is not None {
                self._check_slot_body(
                    [b for b in s.finally_body.body], in_loop, loop_kw
                );
            }
        } elif isinstance(s, uni.MatchStmt) {
            for cs in s.cases {
                self._check_slot_body([b for b in cs.body], in_loop, loop_kw);
            }
        } elif isinstance(s, uni.SwitchStmt) {
            for cs in s.cases {
                self._check_slot_body([b for b in cs.body], in_loop, loop_kw);
            }
        }
    }
}

impl ASTValidationPass._check_slot_else(
    self: ASTValidationPass, else_body: object, in_loop: bool, loop_kw: str
) -> None {
    if else_body is None {
        return;
    }
    if isinstance(else_body, uni.IfStmt) {
        self._check_slot_body([else_body], in_loop, loop_kw);
    } elif isinstance(else_body, uni.ElseStmt) {
        self._check_slot_body([b for b in else_body.body], in_loop, loop_kw);
    }
}

impl ASTValidationPass._slot_emits_keyless_jsx(
    self: ASTValidationPass, stmts: list
) -> bool {
    for s in stmts {
        if isinstance(s, uni.ExprStmt) and isinstance(s.expr, uni.JsxElement) {
            el = s.expr;
            if (
                not el.is_fragment
                and el.dynamic_tag is None
                and not self._slot_has_key_attr(el)
            ) {
                return True;
            }
        } elif isinstance(s, uni.WhileStmt)
        or isinstance(s, uni.InForStmt)
        or isinstance(s, uni.IterForStmt)
        or isinstance(s, uni.WithStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                return True;
            }
        } elif isinstance(s, uni.IfStmt) or isinstance(s, uni.ElseStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                return True;
            }
        } elif isinstance(s, uni.TryStmt) {
            if self._slot_emits_keyless_jsx([b for b in s.body]) {
                return True;
            }
            if s.awaiting_body is not None
            and self._slot_emits_keyless_jsx([b for b in s.awaiting_body.body]) {
                return True;
            }
            for ex in s.excepts {
                if self._slot_emits_keyless_jsx([b for b in ex.body]) {
                    return True;
                }
            }
            if s.else_body is not None
            and isinstance(s.else_body, uni.ElseStmt)
            and self._slot_emits_keyless_jsx([b for b in s.else_body.body]) {
                return True;
            }
            if s.finally_body is not None
            and self._slot_emits_keyless_jsx([b for b in s.finally_body.body]) {
                return True;
            }
        } elif isinstance(s, uni.MatchStmt) or isinstance(s, uni.SwitchStmt) {
            for cs in s.cases {
                if self._slot_emits_keyless_jsx([b for b in cs.body]) {
                    return True;
                }
            }
        }
    }
    return False;
}

impl ASTValidationPass._slot_has_key_attr(
    self: ASTValidationPass, el: uni.JsxElement
) -> bool {
    if el.attributes is None {
        return False;
    }
    for a in el.attributes {
        if (
            isinstance(a, uni.JsxNormalAttribute)
            and a.name is not None
            and a.name.value == "key"
        ) {
            return True;
        }
    }
    return False;
}
