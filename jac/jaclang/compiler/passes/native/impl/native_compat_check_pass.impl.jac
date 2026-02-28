"""Implementation of NativeCompatCheckPass."""

"""Initialize compatibility tracking state."""
impl NativeCompatCheckPass.before_pass(self: NativeCompatCheckPass) -> None {
    self._is_compatible: bool = False;
    self._has_entry_block: bool = False;
    self._disqualify_reason: str = "";
    # Only run when auto_promote_native is explicitly requested on the program
    if not getattr(self.prog, '_auto_promote_native', False) {
        self._disqualify_reason = "auto_promote_native not requested";
        return;
    }
    # Only promote the main entry file, not imported dependencies
    mod_path = self.ir_in.loc.mod_path if self.ir_in.loc else "";
    main_target = getattr(self.prog, '_auto_promote_target', "");
    if mod_path != main_target {
        self._disqualify_reason = "not the main entry file";
        return;
    }
    # Skip files that are already native or are annex/test modules
    if (
        mod_path.endswith('.na.jac')
        or mod_path.endswith('.impl.jac')
        or mod_path.endswith('.test.jac')
    ) {
        self._disqualify_reason = "skipped (already native or annex)";
        return;
    }
    self._is_compatible = True;
}

"""If all checks passed, promote the module to native context."""
impl NativeCompatCheckPass.after_pass(self: NativeCompatCheckPass) -> None {
    if self._is_compatible and self._has_entry_block {
        import from jaclang.jac0core.compiler { _coerce_native_module }
        _coerce_native_module(self.ir_in);
        self.ir_in.gen._auto_promoted_native = True;
    }
}

# ─── Disqualifying visitors ──────────────────────────────────
"""Reject node/edge/walker archetypes; allow obj and enum."""
impl NativeCompatCheckPass.enter_archetype(
    self: NativeCompatCheckPass, nd: uni.Archetype
) -> None {
    if not self._is_compatible {
        return;
    }
    arch_val = nd.arch_type.value if nd.arch_type else "";
    if arch_val in ("node", "edge", "walker") {
        self._is_compatible = False;
        self._disqualify_reason = f"unsupported archetype: {arch_val}";
    }
}

"""Reject async abilities and event-signature abilities."""
impl NativeCompatCheckPass.enter_ability(
    self: NativeCompatCheckPass, nd: uni.Ability
) -> None {
    if not self._is_compatible {
        return;
    }
    if nd.is_async {
        self._is_compatible = False;
        self._disqualify_reason = "async ability not supported";
    } elif isinstance(nd.signature, uni.EventSignature) {
        self._is_compatible = False;
        self._disqualify_reason = "event signature not supported";
    }
}

"""Reject visit statements (walker traversal)."""
impl NativeCompatCheckPass.enter_visit_stmt(
    self: NativeCompatCheckPass, nd: uni.VisitStmt
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "visit statement not supported";
}

"""Reject disengage statements (walker control)."""
impl NativeCompatCheckPass.enter_disengage_stmt(
    self: NativeCompatCheckPass, nd: uni.DisengageStmt
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "disengage statement not supported";
}

"""Reject report statements (walker reporting)."""
impl NativeCompatCheckPass.enter_report_stmt(
    self: NativeCompatCheckPass, nd: uni.ReportStmt
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "report statement not supported";
}

"""Reject yield expressions (generators)."""
impl NativeCompatCheckPass.enter_yield_expr(
    self: NativeCompatCheckPass, nd: uni.YieldExpr
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "yield expression not supported";
}

"""Reject edge operations."""
impl NativeCompatCheckPass.enter_edge_op_ref(
    self: NativeCompatCheckPass, nd: uni.EdgeOpRef
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "edge operations not supported";
}

"""Reject disconnect operations."""
impl NativeCompatCheckPass.enter_disconnect_op(
    self: NativeCompatCheckPass, nd: uni.DisconnectOp
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "disconnect operation not supported";
}

"""Reject typed context blocks (walker-specific)."""
impl NativeCompatCheckPass.enter_typed_ctx_block(
    self: NativeCompatCheckPass, nd: uni.TypedCtxBlock
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "typed context block not supported";
}

"""Reject lambda expressions."""
impl NativeCompatCheckPass.enter_lambda_expr(
    self: NativeCompatCheckPass, nd: uni.LambdaExpr
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "lambda expression not supported";
}

"""Reject inline Python code (::py::)."""
impl NativeCompatCheckPass.enter_py_inline_code(
    self: NativeCompatCheckPass, nd: uni.PyInlineCode
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "inline Python code not supported";
}

"""Reject client blocks (cl { })."""
impl NativeCompatCheckPass.enter_client_block(
    self: NativeCompatCheckPass, nd: uni.ClientBlock
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "client block not supported";
}

"""Reject server blocks (sv { })."""
impl NativeCompatCheckPass.enter_server_block(
    self: NativeCompatCheckPass, nd: uni.ServerBlock
) -> None {
    if not self._is_compatible {
        return;
    }
    self._is_compatible = False;
    self._disqualify_reason = "server block not supported";
}

"""Track entry blocks (with entry { }).

The parser stores 'entry' as a Token kid, not in the name field.
name is only set for targeted entries like 'with entry:__main__'.
"""
impl NativeCompatCheckPass.enter_module_code(
    self: NativeCompatCheckPass, nd: uni.ModuleCode
) -> None {
    for k in nd.kid {
        if isinstance(k, uni.Token) and k.value == "entry" {
            self._has_entry_block = True;
            break;
        }
    }
}
