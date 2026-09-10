"""The analysis ledger follows module objects, never the ids they were handed."""
import gc;
import weakref;
import from jaclang.compiler.driver.progstate { AnalysisLedger }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

obj Probe {
    has name: str = "";
}

test "a claim recorded for one object never answers for another" {
    led = AnalysisLedger();
    a = Probe(name="a");
    led.provided(a).add("CfgSucc");
    assert led.provides(a, "CfgSucc");
    b = Probe(name="b");
    assert not led.provides(b, "CfgSucc");
    assert led.provided(b) == set();
    assert led.provides(a, "CfgSucc");
}

test "a claim dies with the object it describes" {
    led = AnalysisLedger();
    a = Probe(name="a");
    led.mark(a, {"CfgSucc", "TypeOf"});
    assert len(led) == 1;
    del a;
    gc.collect();
    assert len(led) == 0 , "the entry outlived the object it described";
}

test "a stale entry under a reused id starts from nothing" {
    led = AnalysisLedger();
    a = Probe(name="a");
    key = id(a);
    led._tags[key] = {"CfgSucc", "TypeOf"};
    led._owners[key] = weakref.ref(Probe(name="ghost"));
    assert not led.provides(a, "CfgSucc");
    assert led.provided(a) == set();
    led.provided(a).add("TypeOf");
    assert led.provides(a, "TypeOf");
    assert not led.provides(a, "CfgSucc");
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
