"""A module's build record follows module objects, never the ids they were handed."""
import from jaclang.compiler.driver.progstate { AnalysisCaches, ModuleBuild }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Module }

test "a claim recorded for one module never answers for another" {
    caches = AnalysisCaches();
    a = Module.make_stub(inject_name="a");
    caches.build(a).facts.add(AnalysisFact.CFG_SUCC);
    assert caches.provides(a, AnalysisFact.CFG_SUCC);
    b = Module.make_stub(inject_name="b");
    assert not caches.provides(b, AnalysisFact.CFG_SUCC);
    assert caches.build(b).facts == set();
    assert caches.provides(a, AnalysisFact.CFG_SUCC);
}

test "a claim is forgotten when its module leaves the session" {
    caches = AnalysisCaches();
    a = Module.make_stub(inject_name="a");
    caches.mark_facts(a, {AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF});
    assert len(caches.builds) == 1;
    caches.forget_module(Module.make_stub(inject_name="other"));
    assert len(caches.builds) == 1 , "forgetting another module dropped this one's claims";
    caches.forget_module(a);
    assert len(caches.builds) == 0 , "the entry outlived its module's session";
}

test "a stale entry under a reused id starts from nothing" {
    caches = AnalysisCaches();
    a = Module.make_stub(inject_name="a");
    caches.builds[id(a)] = ModuleBuild(
        module=Module.make_stub(inject_name="ghost"),
        done={"SymTabBuildPass"},
        tasks={},
        facts={AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF},
        early={}
    );
    assert not caches.provides(a, AnalysisFact.CFG_SUCC);
    assert caches.peek(a) is None;
    assert caches.build(a).facts == set();
    assert caches.build(a).done == set();
    caches.build(a).facts.add(AnalysisFact.TYPE_OF);
    assert caches.provides(a, AnalysisFact.TYPE_OF);
    assert not caches.provides(a, AnalysisFact.CFG_SUCC);
}

test "replacing or evicting a module forgets its claims" {
    prog = JacProgram();
    mod = prog.compile(
        use_str="with entry { print(1); }",
        file_path="ledger_evict_probe.jac",
        options=CompileOptions(no_cgen=True)
    );
    assert prog.analysis.provides(mod, AnalysisFact.SYM_OF);
    path = JacProgram.hub_key(mod.loc.mod_path);
    prog.invalidate_module(path);
    assert not prog.analysis.provides(mod, AnalysisFact.SYM_OF);
    assert prog.analysis.peek(mod) is None;
}

test "releasing a compile closure forgets every claim" {
    prog = JacProgram();
    prog.compile(
        use_str="with entry { print(1); }",
        file_path="ledger_probe.jac",
        options=CompileOptions(no_cgen=True)
    );
    assert len(prog.analysis.builds) >= 1;
    prog.release_compile_closure();
    assert len(prog.analysis.builds) == 0;
}
