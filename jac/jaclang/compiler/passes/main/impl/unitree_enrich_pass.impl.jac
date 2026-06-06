"""Implementation of UniTreeEnrichPass."""

impl UniTreeEnrichPass.before_pass -> None {
    self.ir_in.gen.analysis.native_compat = NativeCompatFacts();
}

impl UniTreeEnrichPass._mark_native_disqualifier(reason: str) -> None {
    compat = self.ir_in.gen.analysis.native_compat;
    if reason not in compat.disqualifiers {
        compat.disqualifiers.append(reason);
    }
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
    arch_val = nd.arch_type.value if nd.arch_type else "";
    if arch_val in ("node", "edge", "walker") {
        self._mark_native_disqualifier(f"archetype:{arch_val}");
    }
}

impl UniTreeEnrichPass.enter_ability(nd: uni.Ability) -> None {
    if nd.is_async {
        self._mark_native_disqualifier("async ability");
    }
    if isinstance(nd.signature, uni.EventSignature) {
        self._mark_native_disqualifier("event ability");
    }
}

impl UniTreeEnrichPass.enter_visit_stmt(nd: uni.VisitStmt) -> None {
    self._mark_native_disqualifier("visit statement");
}

impl UniTreeEnrichPass.enter_disengage_stmt(nd: uni.DisengageStmt) -> None {
    self._mark_native_disqualifier("disengage statement");
}

impl UniTreeEnrichPass.enter_report_stmt(nd: uni.ReportStmt) -> None {
    self._mark_native_disqualifier("report statement");
}

impl UniTreeEnrichPass.enter_yield_expr(nd: uni.YieldExpr) -> None {
    self._mark_native_disqualifier("yield expression");
}

impl UniTreeEnrichPass.enter_edge_op_ref(nd: uni.EdgeOpRef) -> None {
    self._mark_native_disqualifier("edge operation");
}

impl UniTreeEnrichPass.enter_disconnect_op(nd: uni.DisconnectOp) -> None {
    self._mark_native_disqualifier("disconnect operation");
}

impl UniTreeEnrichPass.enter_typed_ctx_block(nd: uni.TypedCtxBlock) -> None {
    self._mark_native_disqualifier("typed context block");
}

impl UniTreeEnrichPass.enter_lambda_expr(nd: uni.LambdaExpr) -> None {
    self._mark_native_disqualifier("lambda expression");
}

impl UniTreeEnrichPass.enter_py_inline_code(nd: uni.PyInlineCode) -> None {
    self._mark_native_disqualifier("Python inline code");
}

impl UniTreeEnrichPass.enter_client_block(nd: uni.ClientBlock) -> None {
    self._mark_native_disqualifier("client block");
}

impl UniTreeEnrichPass.enter_server_block(nd: uni.ServerBlock) -> None {
    self._mark_native_disqualifier("server block");
}

impl UniTreeEnrichPass.enter_module_code(nd: uni.ModuleCode) -> None {
    for k in nd.kid {
        if isinstance(k, uni.Token) and k.value == "entry" {
            self.ir_in.gen.analysis.native_compat.has_entry = True;
            break;
        }
    }
}

impl UniTreeEnrichPass.exit_module(nd: uni.Module) -> None {
    self.index_code_contexts(nd);
    compat = nd.gen.analysis.native_compat;
    compat.is_compatible = not compat.disqualifiers and compat.has_entry;
}
