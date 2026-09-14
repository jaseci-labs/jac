"""A released module's graph is collectable (#8744 WS5).

The syntax graph's structure edges are adjacency-only (no kernel rows, no
handle registry), so once `JacProgram.release_module` evicts a module from
the hub, the node/edge cycle must be reclaimable by the garbage collector.
This is the memory contract per-module release relies on.
"""
import gc;
import weakref;
import from jaclang.compiler.driver.program { JacProgram }

glob SRC = "def area(r: float) -> float { return 3.14 * r * r; }\n";

def _probe(prog: JacProgram) -> tuple {
    mod = prog.parse_str(SRC, "release_probe.jac");
    assert mod is not None;
    return (
        mod.loc.mod_path,
        weakref.ref(mod),
        weakref.ref(mod.kid[0]),
        weakref.ref(getattr(mod.kid[0], "__jac__")),

    );
}

test "released module trees are garbage collectable" {
    prog = JacProgram();
    (path, mod_ref, kid_ref, anchor_ref) = _probe(prog);
    prog.release_module(JacProgram.hub_key(path));
    gc.collect();
    dead = [mod_ref() is None, kid_ref() is None, anchor_ref() is None];
    assert all(dead) , f"leaked (module, kid, anchor): {dead}";
}

test "replacing a main module releases the previous root" {
    prog = JacProgram();
    for _ in range(4) {
        (path, mod_ref, kid_ref, anchor_ref) = _probe(prog);
        replacement = prog.parse_str(SRC + "# new revision\n", path);
        assert prog.mod.main_mod is replacement;
        gc.collect();
        assert mod_ref() is None and kid_ref() is None and anchor_ref() is None;
        prog.release_module(JacProgram.hub_key(path));
    }
}

test "invalidation releases graph roots in every application context" {
    owner = JacProgram();
    child = JacProgram();
    child.context_root = owner;
    owner.contexts['second'] = child;
    (path, owner_ref, _, _) = _probe(owner);
    (_, child_ref, _, _) = _probe(child);
    owner.record_dependency('consumer.jac', path);
    owner.invalidate_module(JacProgram.hub_key(path));
    gc.collect();
    assert owner_ref() is None and child_ref() is None;
    assert owner.mod.main_mod is None and child.mod.main_mod is None;
    assert owner.transitive_dependents(path) == {JacProgram.hub_key('consumer.jac')};
}

test "analysis sessions own private compiler contexts and release them together" {
    first = JacProgram.for_analysis();
    second = JacProgram.for_analysis();
    first_internal = first._get_compiler().selfhost.program;
    second_internal = second._get_compiler().selfhost.program;
    assert first_internal is not second_internal;
    assert first_internal._get_compiler() is first._get_compiler();
    assert first_internal.source_store is first.source_store;
    assert first.source_store is not second.source_store;
    assert any(first_internal is context for context in first.owned_contexts());
    (_, internal_ref, _, _) = _probe(first_internal);
    first.release_compile_closure();
    gc.collect();
    assert internal_ref() is None;
    assert any(first_internal is context for context in first.owned_contexts());
}

test "execution artifacts survive tree release until their module is invalidated" {
    import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
    program = JacProgram();
    path = JacProgram.hub_key('retained_execution.jac');
    carrier = CodeGenTarget();
    program.hub.artifacts[path] = carrier;
    program.release_compile_closure();
    assert program.hub.artifacts[path] is carrier;
    program.invalidate_module(path);
    assert path not in program.hub.artifacts;
}

def _compile_probe(prog: JacProgram) -> tuple {
    mod = prog.compile(file_path="release_closure_probe.jac", use_str=SRC);
    assert mod is not None;
    return (weakref.ref(mod), weakref.ref(mod.kid[0]));
}

test "a fully compiled module is collectable after release_compile_closure" {
    prog = JacProgram();
    (mod_ref, kid_ref) = _compile_probe(prog);
    prog.release_compile_closure();
    gc.collect();
    dead = [mod_ref() is None, kid_ref() is None];
    assert all(dead) , (
        f"compiled tree pinned after release (module, kid): {dead}; a long-lived "
        "node holds a strong link into it (check the direction of relations to "
        "the builtins scope, codespaces and stub symbols)"
    );
}

test "a compiler phase boundary collects both application and selfhost trees" {
    prog = JacProgram();
    compiler = prog._get_compiler();
    internal = compiler.selfhost.program;
    (_, app_ref, _, _) = _probe(prog);
    (_, internal_ref, _, _) = _probe(internal);
    compiler.release_compile_state(prog);
    assert app_ref() is None;
    assert internal_ref() is None;
    assert not prog.source_store.units;
    assert not internal.source_store.units;
    # Releasing working state must leave the compiler reusable.
    (_, next_ref, _, _) = _probe(prog);
    assert next_ref() is not None;
    compiler.release_compile_state(prog);
    assert next_ref() is None;
}

test "a compiler phase boundary rejects release during an active compile" {
    prog = JacProgram();
    (_, mod_ref, _, _) = _probe(prog);
    prog.scratch.compile_depth += 1;
    try {
        try {
            prog._get_compiler().release_compile_state(prog);
        } except RuntimeError {
            assert mod_ref() is not None;
            return;
        }
        assert False , "compiler state was released while compilation was active";
    } finally {
        prog.scratch.compile_depth -= 1;
        prog._get_compiler().release_compile_state(prog);
    }
}

def _stub_probe(prog: JacProgram) -> any {
    stub = prog.parse_str("value: int\n", "release_bootstrap.pyi");
    return weakref.ref(stub);
}

test "a compiler phase boundary releases stub roots as well as source trees" {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.selfhost { SelfHostCache }
    internal = JacProgram();
    compiler = JacCompiler(_selfhost=SelfHostCache(_program=internal));
    internal._compiler = compiler;
    program = JacProgram();
    program._compiler = compiler;
    app_stub = _stub_probe(program);
    bootstrap_stub = _stub_probe(internal);
    compiler.release_compile_state(program);
    assert app_stub() is None , "completed application still owns its stub trees";
    assert bootstrap_stub() is None , "completed compiler still owns bootstrap stubs";
}

test "activating the catalog releases the compiler's bootstrap stub trees" {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.selfhost { SelfHostCache }
    internal = JacProgram();
    compiler = JacCompiler(_selfhost=SelfHostCache(_program=internal));
    internal._compiler = compiler;
    bootstrap_stub = _stub_probe(internal);
    assert compiler.ensure_stub_catalog() is not None;
    gc.collect();
    assert bootstrap_stub() is None , "the active catalog still retains bootstrap stubs";
}

glob STUB_SRC: str = (
         "import sys;\n"
         "with entry {\n"
         "    d: dict[str, int] = {\"a\": 1};\n"
         "    names: list[str] = sorted(list(d.keys()));\n"
         "    sys.stderr.write(\", \".join(names) + \"\\n\");\n"
         "}\n"
     );

def _stub_modules(prog: JacProgram) -> dict {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    out: dict = {};
    for p in [prog, Jac.get_compiler().selfhost.program] {
        for (path, mod) in p.mod.hub.items() {
            if path.endswith(".pyi") {
                out[path] = weakref.ref(mod);
            }
        }
    }
    return out;
}

test "typeshed never enters the hub and builtins bindings survive a release" {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    prog = JacProgram();
    first = prog.compile(file_path="stub_retention_probe.jac", use_str=STUB_SRC);
    assert first is not None and not prog.errors_had , f"{[
        str(e) for e in prog.errors_had
    ]}";
    stubs = _stub_modules(prog);
    assert not stubs , (
        f"typeshed modules found in a program hub: {sorted(stubs)}; the stub "
        "catalog serves them and nothing should parse a stdlib .pyi into a hub"
    );
    prog.release_compile_closure();
    Jac.get_compiler().selfhost.program.release_compile_closure();
    gc.collect();
    second = prog.compile(
        file_path="stub_retention_probe_2.jac", use_str=STUB_SRC + "# second unit\n"
    );
    assert second is not None and not prog.errors_had , f"{[
        str(e) for e in prog.errors_had
    ]}";
}
