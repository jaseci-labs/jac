"""Implementation of UniTreeEnrichPass."""

impl UniTreeEnrichPass.before_pass -> None {
    self._native_has_disqualifier: bool = False;
    self._native_has_entry: bool = False;
}


impl UniTreeEnrichPass.enter_name(nd: uni.Name) -> None {
    if nd?.js_decl_kind is not None {
        return;
    }
    if nd.name_of is nd {
        parent = nd.parent;
        try {
            if isinstance(parent, uni.ParamVar) {
                nd.js_decl_kind = "param";
                return;
            }
        } except Exception {
            pass;
        }
        nd.js_decl_kind = "let";
    }
}


impl UniTreeEnrichPass.enter_archetype(nd: uni.Archetype) -> None {
    if not self._native_has_disqualifier {
        arch_val = nd.arch_type.value if nd.arch_type else "";
        if arch_val in ("node", "edge", "walker") {
            self._native_has_disqualifier = True;
        }
    }
}

impl UniTreeEnrichPass.enter_ability(nd: uni.Ability) -> None {
    if not self._native_has_disqualifier {
        if nd.is_async or isinstance(nd.signature, uni.EventSignature) {
            self._native_has_disqualifier = True;
        }
    }
}

impl UniTreeEnrichPass.enter_visit_stmt(nd: uni.VisitStmt) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_disengage_stmt(nd: uni.DisengageStmt) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_report_stmt(nd: uni.ReportStmt) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_yield_expr(nd: uni.YieldExpr) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_edge_op_ref(nd: uni.EdgeOpRef) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_disconnect_op(nd: uni.DisconnectOp) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_typed_ctx_block(nd: uni.TypedCtxBlock) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_lambda_expr(nd: uni.LambdaExpr) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_py_inline_code(nd: uni.PyInlineCode) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_client_block(nd: uni.ClientBlock) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_server_block(nd: uni.ServerBlock) -> None {
    self._native_has_disqualifier = True;
}

impl UniTreeEnrichPass.enter_module_code(nd: uni.ModuleCode) -> None {
    for k in nd.kid {
        if isinstance(k, uni.Token) and k.value == "entry" {
            self._native_has_entry = True;
            break;
        }
    }
}

impl UniTreeEnrichPass.exit_module(nd: uni.Module) -> None {
    nd.gen.native_compat = not self._native_has_disqualifier and self._native_has_entry;
}
