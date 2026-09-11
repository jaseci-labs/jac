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
