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

"""Validate 'pass' and 'new' keywords are not used as identifiers."""
impl ASTValidationPass.enter_name(self: ASTValidationPass, nd: uni.Name) -> None {
    if nd.value == "pass" {
        self.emit(E0010, node_override=nd, keyword="pass");
    } elif nd.value == "new" {
        # Only flag 'new' as a standalone identifier, not as an attribute
        # access (e.g. hmac.new is valid Python interop).
        is_attr = isinstance(nd.parent, uni.AtomTrailer)
        and nd.parent.is_attr
        and nd.parent.right is nd;
        if not is_attr {
            self.emit(E0010, node_override=nd, keyword="new");
        }
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
    non_assignable = {Tok.KW_ROOT,Tok.KW_SUPER};
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
    seen_methods: set[str] = set();
    for item in body {
        if isinstance(item, uni.Ability) and item.name_ref is not None {
            # Skip @overload-decorated methods — duplicates are expected.
            has_overload = False;
            if item.decorators is not None {
                for dec in item.decorators {
                    if isinstance(dec, uni.Name) and dec.value == "overload" {
                        has_overload = True;
                    }
                }
            }
            if has_overload {
                continue;
            }
            mname = item.name_ref.value;
            if mname in seen_methods {
                self.emit(E0076, node_override=item.name_ref, name=mname);
            }
            seen_methods.add(mname);
        }
    }
}

"""E0071: validate bare except is the last except clause."""
impl ASTValidationPass.enter_try_stmt(
    self: ASTValidationPass, nd: uni.TryStmt
) -> None {
    if len(nd.excepts) == 0 and nd.finally_body is None {
        self.emit(E0040, node_override=nd);
    }
    # E0071: bare except must be last
    for (i, exc) in enumerate(nd.excepts) {
        if exc.ex_type is None and i < len(nd.excepts) - 1 {
            self.emit(E0071, node_override=exc);
        }
    }
}
