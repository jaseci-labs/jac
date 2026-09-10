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

test "direct compiler source compilation retains analysis across nested import eviction" {
    import marshal;
    import tempfile;
    import from pathlib { Path }
    import from unittest.mock { patch }
    import jaclang.compiler.driver.compiler as compiler_mod;
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    compiler = JacProgram()._get_compiler();
    program = compiler.selfhost.program;
    original_run = compiler_mod.run_pass;
    evictions: list[str] = [];

    def run_and_evict(pass_cls: any, mod: any, prog: any, **kwargs: any) -> any {
        result = original_run(pass_cls, mod, prog, **kwargs);
        if pass_cls.__name__ == "CFGBuildPass" and prog is program {
            evictions.append(mod.loc.mod_path);
            compiler.selfhost.evict_unit(mod.loc.mod_path, None, collect=False);
        }
        return result;
    }

    with tempfile.TemporaryDirectory() as directory {
        source = str(Path(directory) / "direct_compile.jac");
        with patch.object(compiler_mod, "run_pass", side_effect=run_and_evict) {
            mod = compiler.compile(
                source,
                target_program=program,
                use_str="glob answer: int = 42;\n",
                options=CompileOptions(force_codespace="server")
            );
        }
        assert evictions;
        assert mod.gen.py_bytecode is not None;
        namespace: dict = {"__name__": "direct_compile", "__file__": source};
        exec(marshal.loads(mod.gen.py_bytecode), namespace);
        assert namespace["answer"] == 42;
        assert not program.mod.hub;
    }
}

test "programs hydrate independent semantic objects from shared catalog bytes" {
    first = JacProgram();
    second = JacProgram();
    first._get_compiler().ensure_stub_catalog();
    second._get_compiler().ensure_stub_catalog();
    left = first.stub_catalog();
    right = second.stub_catalog();
    assert left is not None and right is not None;
    assert left is not right;
    assert left.buf is right.buf;
    left_type = first.get_type_evaluator().prefetch.literal_string_class;
    right_type = second.get_type_evaluator().prefetch.literal_string_class;
    assert left_type is not None and right_type is not None;
    assert left_type.shared is not right_type.shared;
    assert first.stub_catalog() is left;
}

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


test "releasing a closure releases the catalog and evaluator together" {
    import os;
    import from unittest.mock { patch }
    prog = JacProgram();
    def analyze -> tuple {
        mod = prog.compile(file_path="catalog_session_probe.jac", use_str=STUB_SRC);
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        return (
            weakref.ref(prog.get_type_evaluator()),
            weakref.ref(prog.stub_catalog())
        );
    }
    (evaluator, catalog) = analyze();
    with patch.dict(os.environ, {"JAC_UNIT_COLLECT_EVERY": "1"}) {
        prog.release_compile_closure();
    }
    assert catalog() is None , "a released catalog is still owned outside its session";
    assert evaluator() is None , "a released evaluator is still owned outside its session";
}

test "compiler execution retains its own analysis until the outer import completes" {
    import from jaclang.compiler.driver.selfhost { SelfHostCache }
    prog = JacProgram();
    cache = SelfHostCache(_program=prog);
    (path, mod_ref, kid_ref, anchor_ref) = _probe(prog);
    cache.enter_execution();
    try {
        cache.enter_execution();
        try {
            cache.evict_unit(path, None, collect=False);
            assert prog.find_module(path) is not None;
        } finally {
            cache.exit_execution();
        }
        assert prog.find_module(path) is not None;
    } finally {
        cache.exit_execution();
    }
    assert prog.find_module(path) is None;
    gc.collect();
    assert mod_ref() is None and kid_ref() is None and anchor_ref() is None;
}

test "closure release drops native products while retaining execution carriers" {
    import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
    import from jaclang.compiler.driver.native_iface { NativeIface }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    program = JacProgram();
    registry = program.native_units();
    iface = NativeIface(module="release", prefix="release");
    product = registry.record("release.jac", iface, CompileOptions());
    product.object_bytes = b"object";
    product.bitcode = b"bitcode";
    carrier = CodeGenTarget();
    carrier.native_iface = iface;
    carrier.native_object = product.object_bytes;
    carrier.native_bitcode = product.bitcode;
    program.hub.artifacts[product.path] = carrier;
    program.release_compile_closure(collect=False);
    assert not registry.entries;
    assert program.hub.artifacts[product.path] is carrier;
    assert carrier.native_object is None and carrier.native_bitcode is None;
    assert carrier.native_iface is iface;
}
