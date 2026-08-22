import from jaclang.jac0core.unitree { Import, Module }

glob PREFIX_NATIVE_FRONTIER: int = 1;
import from jaclang.jac0core.passes.transform { Alert }
import from jaclang.jac0core.passes.ast_validation_pass { ASTValidationPass }

obj PrefixAlertRow {
    has severity: int = 0,
        code: str = "",
        msg: str = "",
        help_text: str = "",
        first_line: int = 0,
        col_start: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        pass_idx: int = 0;
}

obj PrefixRunResult {
    has executed: int = 0,
        clause: str = "",
        detail: str = "",
        rows: list[PrefixAlertRow] = [];
}

def _row_of(alert: Alert, severity: int, pass_idx: int) -> PrefixAlertRow {
    code = alert.code.code if alert.code is not None else "";
    help_text = alert.help_text if alert.help_text is not None else "";
    return PrefixAlertRow(
        severity=severity,
        code=code,
        msg=alert.msg,
        help_text=help_text,
        first_line=alert.loc.first_line,
        col_start=alert.loc.col_start,
        pos_start=alert.loc.pos_start,
        pos_end=alert.loc.pos_end,
        pass_idx=pass_idx
    );
}

def _harvest(
    rows: list[PrefixAlertRow],
    errors: list[Alert],
    warnings: list[Alert],
    pass_idx: int
) {
    for e in errors {
        rows.append(_row_of(e, 1, pass_idx));
    }
    for w in warnings {
        rows.append(_row_of(w, 0, pass_idx));
    }
}

def run_prefix_passes(mod: Module, claimed_n: int) -> PrefixRunResult {
    out = PrefixRunResult();
    for imp in mod.get_all_sub_nodes(Import) {
        if imp.is_absorb {
            out.clause = "absorbed-mod-present";
            out.detail = "the module carries an absorb import";
            return out;
        }
    }
    _cap = claimed_n if claimed_n < PREFIX_NATIVE_FRONTIER else PREFIX_NATIVE_FRONTIER;
    if _cap >= 1 {
        p1 = ASTValidationPass(ir_in=mod);
        _harvest(out.rows, p1.errors_had, p1.warnings_had, 0);
        out.executed = 1;
    }
    if claimed_n > out.executed and not out.clause {
        out.clause = "prefix-declined";
        out.detail = (
            f"the native frontier is seat {PREFIX_NATIVE_FRONTIER} "
            "(ASTValidationPass); later seats run staged until their "
            "native execution is proven"
        );
    }
    return out;
}
