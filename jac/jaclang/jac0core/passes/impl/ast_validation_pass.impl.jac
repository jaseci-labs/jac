"""Implementation for AST validation pass.

Checks moved here from the parser to follow the modern compiler pattern of
'parse permissively, validate later'. Each enter_* visitor validates a specific
structural invariant on the already-constructed AST node.

Uses the structured diagnostic code system (self.emit) for precise, machine-
readable error reporting with suppression support.
"""
"""Validate try statement has at least one except or finally block."""
impl ASTValidationPass.enter_try_stmt(
    self: ASTValidationPass, nd: uni.TryStmt
) -> None {
    if len(nd.excepts) == 0 and nd.finally_body is None {
        self.emit(E0040, node_override=nd);
    }
}

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

"""Validate import statement has at least one item."""
impl ASTValidationPass.enter_import(self: ASTValidationPass, nd: uni.Import) -> None {
    if nd.items is not None
    and len(nd.items) == 0
    and (nd.clib_decls is None or len(nd.clib_decls) == 0) {
        self.emit(E0044, node_override=nd);
    }
}
