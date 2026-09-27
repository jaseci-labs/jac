"""The analysis ledger follows module objects, never the ids they were handed."""
import from jaclang.compiler.driver.progstate { AnalysisLedger }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Module }

test "a claim recorded for one module never answers for another" {
    led = AnalysisLedger();
    a = Module.make_stub(inject_name="a");
    led.provided(a).add(AnalysisFact.CFG_SUCC);
    assert led.provides(a, AnalysisFact.CFG_SUCC);
    b = Module.make_stub(inject_name="b");
    assert not led.provides(b, AnalysisFact.CFG_SUCC);
    assert led.provided(b) == set();
    assert led.provides(a, AnalysisFact.CFG_SUCC);
}

test "a claim is forgotten when its module leaves the session" {
    led = AnalysisLedger();
    a = Module.make_stub(inject_name="a");
    led.mark(a, {AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF});
    assert len(led) == 1;
    led.forget(Module.make_stub(inject_name="other"));
    assert len(led) == 1 , "forgetting another module dropped this one's claims";
    led.forget(a);
    assert len(led) == 0 , "the entry outlived its module's session";
}

test "a stale entry under a reused id starts from nothing" {
    led = AnalysisLedger();
    a = Module.make_stub(inject_name="a");
    key = id(a);
    led._tags[key] = {AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF};
    led._owners[key] = Module.make_stub(inject_name="ghost");
    assert not led.provides(a, AnalysisFact.CFG_SUCC);
    assert led.provided(a) == set();
    led.provided(a).add(AnalysisFact.TYPE_OF);
    assert led.provides(a, AnalysisFact.TYPE_OF);
    assert not led.provides(a, AnalysisFact.CFG_SUCC);
}

test "replacing or evicting a module forgets its claims" {
    prog = JacProgram();
    mod = prog.compile(
        use_str="with entry { print(1); }",
        file_path="ledger_evict_probe.jac",
        options=CompileOptions(no_cgen=True)
    );
    ledger = prog.analysis.analyses_run;
    assert ledger.provides(mod, AnalysisFact.SYM_OF);
    path = JacProgram.hub_key(mod.loc.mod_path);
    prog.invalidate_module(path);
    assert not ledger.provides(mod, AnalysisFact.SYM_OF);
    assert id(mod) not in prog.analysis.task_owners;
}

test "releasing a compile closure forgets every claim" {
    prog = JacProgram();
    prog.compile(
        use_str="with entry { print(1); }",
        file_path="ledger_probe.jac",
        options=CompileOptions(no_cgen=True)
    );
    assert len(prog.analysis.analyses_run) >= 1;
    prog.release_compile_closure();
    assert len(prog.analysis.analyses_run) == 0;
}
