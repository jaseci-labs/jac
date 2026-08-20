"""Diagnostics as data: passes accumulate, the driver delivers (epic #8201).

`Transform.emit` used to reach through the `JacProgram` handle on every
diagnostic and read project config per emit, which made every pass body own
an unwaivable Python seam. The redesigned flow is one-directional data:
emission appends plain `Alert` objects to the pass-local `errors_had` /
`warnings_had` lists, and the Python driver (`run_pass` /
`JacCompiler.run_schedule`) delivers them to the program ledger after the
pass body finishes -- applying suppression policy at that boundary. These
tests pin the contract: accumulation never touches the program mid-pass,
delivery preserves emission order, suppression is decided from the
pre-resolved `DiagnosticPolicy` (emit-time when stamped, delivery-time
always), and `Transform.ice` still records its E9001 before raising even
though the constructor never returns.
"""

import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compiler { deliver_alerts, run_pass }
import from jaclang.jac0core.diagnostics { Category, DiagnosticInfo, E1030, Severity }
import from jaclang.jac0core.passes { Transform }
import from jaclang.jac0core.passes.transform { DiagnosticPolicy }
import from jaclang.jac0core.program { JacProgram }

glob PROBE_ERR = DiagnosticInfo(
         code="E9901",
         severity=Severity.ERROR,
         category=Category.SEMANTIC,
         message_template="probe error {tag}"
     ),
     PROBE_WARN = DiagnosticInfo(
         code="W9902",
         severity=Severity.WARNING,
         category=Category.SEMANTIC,
         message_template="probe warning {tag}"
     );

"""A pass that emits and observes the program ledger mid-run."""
obj ProbeEmitPass(Transform) {
    has mid_run_prog_errors: int = -1,
        mid_run_prog_warnings: int = -1,
        mid_run_local_errors: int = -1,
        emit_results: list[bool] = [];

    def transform(ir_in: uni.Module) -> uni.Module {
        self.emit_results.append(self.emit(PROBE_ERR, tag="first"));
        self.emit_results.append(self.emit(PROBE_WARN, tag="second"));
        self.emit_results.append(self.emit(PROBE_ERR, tag="third"));
        self.mid_run_prog_errors = len(self.prog.errors_had);
        self.mid_run_prog_warnings = len(self.prog.warnings_had);
        self.mid_run_local_errors = len(self.errors_had);
        return ir_in;
    }
}

"""A pass that dies through `Transform.ice` after recording one alert."""
obj ProbeIcePass(Transform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        raise RuntimeError(self.ice("probe detonation"));
    }
}

def _parse(prog: JacProgram, source: str) -> uni.Module {
    return prog.parse_str(source, "<alert_delivery_test>");
}


test "emission accumulates pass-locally and never touches the program mid-run" {
    prog = JacProgram();
    mod = _parse(prog, "with entry { x = 1; }");
    inst = run_pass(ProbeEmitPass, mod, prog);
    assert inst.mid_run_prog_errors == 0 , (
        f"emit reached the program ledger mid-pass: "
        f"{inst.mid_run_prog_errors} error(s) visible during transform"
    );
    assert inst.mid_run_prog_warnings == 0 , (
        "emit reached the program warning ledger mid-pass"
    );
    assert inst.mid_run_local_errors == 2 , (
        f"pass-local accumulation broken: {inst.mid_run_local_errors} != 2"
    );
    assert inst.emit_results == [True, True, True] , (
        f"un-suppressed emits must report True: {inst.emit_results}"
    );
}


test "delivery lands alerts on the program in emission order" {
    prog = JacProgram();
    mod = _parse(prog, "with entry { x = 1; }");
    run_pass(ProbeEmitPass, mod, prog);
    msgs = [a.msg for a in prog.errors_had];
    assert msgs == ["probe error first", "probe error third"] , (
        f"delivered errors out of order or missing: {msgs}"
    );
    warn_msgs = [a.msg for a in prog.warnings_had];
    assert warn_msgs == ["probe warning second"] , (
        f"delivered warnings wrong: {warn_msgs}"
    );
    assert prog.errors_had[0].code is PROBE_ERR , (
        "delivered Alert lost its DiagnosticInfo identity"
    );
}


test "a policy stamped on the pass suppresses at emit time" {
    prog = JacProgram();
    mod = _parse(prog, "with entry { x = 1; }");
    policy = DiagnosticPolicy(suppress_codes=["E9901"]);
    inst = run_pass(ProbeEmitPass, mod, prog, policy=policy);
    assert inst.emit_results == [False, True, False] , (
        f"suppressed emits must report False: {inst.emit_results}"
    );
    assert not inst.errors_had , ("suppressed alerts must not accumulate on the pass");
    assert not prog.errors_had , (
        f"suppressed alerts leaked into delivery: {[str(a) for a in prog.errors_had]}"
    );
    assert [a.msg for a in prog.warnings_had] == ["probe warning second"];
}


test "an unstamped pass accumulates everything and delivery suppresses" {
    prog = JacProgram();
    mod = _parse(prog, "with entry { x = 1; }");
    inst = ProbeEmitPass(ir_in=mod, prog=prog);
    assert len(inst.errors_had) == 2 , (
        "a policy-free pass must accumulate every emission"
    );
    assert not prog.errors_had , ("direct construction must not deliver by itself");
    deliver_alerts(
        inst.errors_had,
        inst.warnings_had,
        prog,
        DiagnosticPolicy(suppress_codes=["E9901"])
    );
    assert not prog.errors_had , (
        f"delivery-time suppression failed: {[str(a) for a in prog.errors_had]}"
    );
    assert [a.msg for a in prog.warnings_had] == ["probe warning second"];
}


test "inline jac:ignore suppression holds through the policy object" {
    prog = JacProgram();
    mod = _parse(prog, "with entry {\n    x = 1;  # jac:ignore[E1030]\n}\n");
    policy = DiagnosticPolicy();
    assert policy.is_suppressed(E1030, mod.loc) is False , (
        "module-level loc (line 1) must not inherit the line-2 ignore"
    );
    target: uni.Assignment | None = None;
    for nd in mod.get_all_sub_nodes(uni.Assignment) {
        target = nd;
    }
    assert target is not None;
    assert policy.is_suppressed(E1030, target.loc) , (
        "a jac:ignore[E1030] comment on the alert line must suppress E1030"
    );
    assert policy.is_suppressed(PROBE_ERR, target.loc) is False , (
        "an unrelated code must not be suppressed by the E1030 ignore"
    );
}


test "ice records its E9001 and still raises through the driver" {
    prog = JacProgram();
    mod = _parse(prog, "with entry { x = 1; }");
    blew_up = False;
    try {
        run_pass(ProbeIcePass, mod, prog);
    } except RuntimeError as e {
        blew_up = True;
        assert "ProbeIcePass" in str(e);
        assert "probe detonation" in str(e);
    }
    assert blew_up , "Transform.ice must still raise";
    codes = [
        a.code.code
        for a in prog.errors_had
        if a.code is not None
    ];
    assert "E9001" in codes , (
        f"the ICE alert was lost when the constructor raised: "
        f"{[str(a) for a in prog.errors_had]}"
    );
}
