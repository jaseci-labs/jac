"""The product store follows module objects, never the ids they were handed."""
import gc;
import weakref;
import from jaclang.compiler.pipeline.products {
    ProductStore,
    ModuleProducts,
    product_path
}
import from jaclang.compiler.ir.identity { GraphId }
import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.pipeline.contracts { AnalysisFact }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.pipeline.contracts { CompilationProduct, ProductRecord }

obj ReleaseAnotherGraph {
    has store: ProductStore,
        graph_id: int;

    def __del__ {
        self.store.drop_module(self.graph_id);
    }
}

test "collecting a product can release another graph during cleanup" {
    store = ProductStore();
    first = Module.make_stub(inject_name="first");
    second = Module.make_stub(inject_name="second");
    store.module(first);
    store.module(second);
    first_result = (product_path(first), CompilationProduct.SPACES, "");
    second_result = (product_path(second), CompilationProduct.SPACES, "");
    store.result_owners[first_result] = GraphId(id(first));
    store.result_owners[second_result] = GraphId(id(second));
    store._values[first_result] = ProductRecord[object](
        value=ReleaseAnotherGraph(store=store, graph_id=id(second)), version=1
    );
    store._values[second_result] = ProductRecord[object](value=42, version=1);
    store.drop_module(id(first));
    assert len(store) == 0;
    assert not store.result_owners;
    assert not store._values;
}


test "a claim recorded for one object never answers for another" {
    led = ProductStore();
    a = Module.make_stub(inject_name="a");
    led.provided(a).add(AnalysisFact.CFG_SUCC);
    assert led.provides(a, AnalysisFact.CFG_SUCC);
    b = Module.make_stub(inject_name="b");
    assert not led.provides(b, AnalysisFact.CFG_SUCC);
    assert led.provided(b) == set();
    assert led.provides(a, AnalysisFact.CFG_SUCC);
}

test "a claim dies with the object it describes" {
    led = ProductStore();
    a = Module.make_stub(inject_name="a");
    led.mark(a, {AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF});
    assert len(led) == 1;
    del a;
    gc.collect();
    assert len(led) == 0 , "the entry outlived the object it described";
}

test "a stale entry under a reused id starts from nothing" {
    led = ProductStore();
    a = Module.make_stub(inject_name="a");
    key = id(a);
    ghost = Module.make_stub(inject_name="ghost");
    led.modules[key] = ModuleProducts(
        owner=weakref.ref(ghost),
        identity=GraphId(key),
        path=product_path(ghost),
        facts={AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF}
    );
    assert not led.provides(a, AnalysisFact.CFG_SUCC);
    assert led.provided(a) == set();
    led.provided(a).add(AnalysisFact.TYPE_OF);
    assert led.provides(a, AnalysisFact.TYPE_OF);
    assert not led.provides(a, AnalysisFact.CFG_SUCC);
}

test "releasing a compile closure forgets every claim" {
    prog = JacProgram();
    prog.compile(
        use_str="def value -> int { return 1; }",
        file_path="ledger_probe.jac",
        options=CompileOptions(no_cgen=True, no_ir_cache=True)
    );
    assert not prog.errors_had , [str(error) for error in prog.errors_had];
    assert len(prog.analysis) >= 1;
    prog.release_compile_closure();
    assert len(prog.analysis) == 0;
}
