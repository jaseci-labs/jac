"""Dependency edges belong to source revisions, not resident module trees."""
import os;
import from jaclang.compiler.driver.progstate { DepGraph }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compilation_context { CompilationContext }

test "replacement commits only a complete dependency set" {
    edges = DepGraph();
    consumer = os.path.realpath('consumer.jac');
    old = os.path.realpath('old.jac');
    fresh = os.path.realpath('fresh.jac');
    edges.record(consumer, old);
    edges.begin(consumer);
    edges.record(consumer, fresh);
    edges.finish(consumer, False);
    assert edges.transitive_dependents(old) == {consumer};
    assert edges.transitive_dependents(fresh) == {consumer};
    edges.begin(consumer);
    edges.record(consumer, fresh);
    edges.finish(consumer, True);
    assert not edges.transitive_dependents(old);
    assert edges.transitive_dependents(fresh) == {consumer};
    assert old not in edges.dependents;
}

test "invalidation preserves recovery and cross context fanout" {
    owner = JacProgram();
    context = JacProgram();
    context.context_root = owner;
    owner.contexts['app'] = CompilationContext(context.deps, context);
    library = os.path.realpath('library.jac');
    middle = os.path.realpath('middle.jac');
    consumer = os.path.realpath('consumer.jac');
    owner.record_dependency(middle, library);
    context.record_dependency(consumer, middle);
    for _ in range(4) {
        owner.invalidate_module(middle);
        owner.invalidate_module(library);
        assert owner.transitive_dependents(library) == {middle, consumer};
        assert context.transitive_dependents(library) == {middle, consumer};
    }
}

test "cycles exclude their origin and forget removes outgoing edges" {
    edges = DepGraph();
    first = os.path.realpath('first.jac');
    second = os.path.realpath('second.jac');
    edges.record(first, second);
    edges.record(second, first);
    assert edges.transitive_dependents(first) == {second};
    edges.forget(first);
    assert not edges.transitive_dependents(second);
    assert edges.transitive_dependents(first) == {second};
    edges.clear();
    assert not edges.dependencies and not edges.dependents and not edges.pending;
}
