"""Placement converges without repeatedly solving an unchanged import graph."""

import os;
import tempfile;
import from unittest.mock { patch }
import from tests.support { JAC_ROOT }
import jaclang.compiler.frontend.unitree as uni;
import jaclang.compiler.placement.placement_solver as solver;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.roles { BodyRole }

def _compile -> tuple[JacProgram, uni.Module] {
    prog = JacProgram();
    path = os.path.join(
        JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "infer_xmod_app.jac"
    );
    mod = prog.compile(path, no_cgen=True);
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    return (prog, mod);
}

def _closure_module(prog: JacProgram, path: str, source: str) -> uni.Module {
    with open(path, "w") as stream {
        stream.write(source);
    }
    prog.invalidate_module(path);
    mod = prog.compile(
        path,
        options=CompileOptions(
            no_cgen=True, force_codespace="server", skip_native_engine=True
        )
    );
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    return mod;
}


test "closure validation enumerates each module once per invocation" {
    with tempfile.TemporaryDirectory(prefix="jac-placement-closure-") as tmp {
        source = "def f0 -> int { return 1; }\n";
        for i in range(1, 48) {
            source += f"def f{i} -> int {{ return f{i - 1}(); }}\n";
        }
        prog = JacProgram();
        mod = _closure_module(prog, os.path.join(tmp, "helpers.jac"), source);
        top = solver._named_top_element(mod, "f47");
        assert top is not None;
        solver.placement_work(prog).refs(mod);
        reads: list[int] = [];
        original: any = vars(uni.Module)["elements"].fget;
        def elements(module: uni.Module) -> list[uni.UniNode] {
            if module is mod {
                reads.append(id(module));
            }
            return original(module);
        }
        with patch.object(uni.Module, "elements", property(elements)) {
            assert solver._closure_pullable(top, mod, prog, set());
            assert solver._closure_pullable(top, mod, prog, set());
        }
        assert len(reads) == 2 , len(reads);
    }
}


test "closure indexes do not outlive edits or hide denied dependencies" {
    with tempfile.TemporaryDirectory(prefix="jac-placement-closure-edit-") as tmp {
        prog = JacProgram();
        path = os.path.join(tmp, "helpers.jac");
        for (source, allowed) in [
            ("def value -> int { return 1; }", True),
            ("import os;\ndef value -> int { return len(os.sep); }", False),
            ("node Doc {}\ndef:pub value -> int { return 1; }", False),
            (
                "node Doc { can seen with entry { print(root); } }\n"
                    + "def value -> int { doc = Doc(); return 1; }",
                False
            ),
            ("def value -> int { return 2; }", True)
        ] {
            mod = _closure_module(prog, path, source);
            top = solver._named_top_element(mod, "value");
            assert top is not None;
            assert solver._closure_pullable(top, mod, prog, set()) == allowed , (
                source,
                allowed
            );
        }
    }
}


test "lazy materialization refreshes an index before following added declarations" {
    prog = JacProgram();
    mod = prog.parse_str(
        "import from late { ready }\ndef start -> int { return 1; }",
        "/tmp/placement-lazy-index.jac"
    );
    imp = next(
        top
        for top in mod.body
        if isinstance(top, uni.Import)
    );
    start = next(
        top
        for top in mod.body
        if isinstance(top, uni.Ability)
    );
    extra = prog.parse_str(
        "def ready -> int { return 1; }\n"
            + "node Blocked { can seen with entry { print(root); } }",
        "/tmp/placement-lazy-extra.jac"
    );
    ready = next(
        top
        for top in extra.body
        if isinstance(top, uni.Ability)
    );
    blocked = next(
        top
        for top in extra.body
        if isinstance(top, uni.Archetype)
    );
    references: dict[int, set[int]] = {id(start): {id(imp)}, id(ready): {id(blocked)}};
    work = solver.placement_work(prog);
    def refs(module: uni.Module, top: uni.UniNode) -> set[int] {
        return references.get(id(top), set());
    }
    with patch.object(solver, "_ref_top_ids", side_effect=refs) {
        work.refresh(mod);
        before = work.refs(mod);
        def materialize(imported: uni.Import, program: JacProgram) -> uni.Module {
            assert imported is imp;
            assert program is prog;
            mod.add_kids_right(list(extra.body), role=BodyRole);
            work.refresh(mod);
            assert work.refs(mod) is not before;
            return mod;
        }
        with patch.object(solver, "_import_source_module", side_effect=materialize), patch.object(
            solver, "_named_top_element", return_value=ready
        ) {
            assert not solver._closure_pullable(start, mod, prog, set());
        }
    }
}


test "unchanged and unrelated modules do not rescan the solved import graph" {
    (prog, mod) = _compile();
    solver.solve_program_placement(mod, prog);
    with patch.object(
        solver, "_pull_boundary_import", wraps=solver._pull_boundary_import
    ) as pulls {
        with patch.object(solver, "_ref_top_ids", wraps=solver._ref_top_ids) as refs {
            solver.solve_program_placement(mod, prog);
            solver.solve_program_placement(mod, prog);
            other = prog.parse_str(
                "def unrelated -> int { return 1; }", "/tmp/placement-unrelated.jac"
            );
            solver.solve_program_placement(other, prog);
            assert pulls.call_count == 0 , pulls.call_count;
            assert refs.call_count == 0 , refs.call_count;
        }
    }
}

test "symbol refresh invalidates references while placement changes reuse them" {
    (prog, mod) = _compile();
    work = solver.placement_work(prog);
    with patch.object(solver, "_ref_top_ids", wraps=solver._ref_top_ids) as refs {
        work.refresh(mod);
        before = work.refs(mod);
        assert refs.call_count == len(mod.body);
        work.changed(mod);
        assert work.refs(mod) is before;
        assert refs.call_count == len(mod.body);
        work.refresh(mod);
        assert work.refs(mod) == before;
        assert work.refs(mod) is not before;
        assert refs.call_count == 2 * len(mod.body);
    }
}

test "an interrupted solve retains its pending import for the next attempt" {
    (prog, mod) = _compile();
    work = solver.placement_work(prog);
    work.changed(mod);
    with patch.object(
        solver, "_pull_boundary_import", side_effect=RuntimeError("interrupted")
    ) {
        try {
            solver.solve_program_placement(mod, prog);
            assert False , "the interrupted solve must propagate its exception";
        } except RuntimeError {}
    }
    assert work.pending;
    assert not work.solving;
    solver.solve_program_placement(mod, prog);
    assert not work.pending;
    with patch.object(
        solver, "_pull_boundary_import", wraps=solver._pull_boundary_import
    ) as pulls {
        solver.solve_program_placement(mod, prog);
        assert pulls.call_count == 0;
    }
}

test "replacement during solving preserves the active queue and wakes importers" {
    (prog, mod) = _compile();
    work = solver.placement_work(prog);
    target = next(
        m
        for m in work.modules.values()
        if m.name == "infer_xmod_util"
    );
    dependent_edges = set(work.readers.get(id(target), set()));
    assert dependent_edges;
    work.solving = True;
    try {
        replacement = JacProgram().parse_str(
            "def helper -> int { return 1; }", target.loc.mod_path
        );
        prog.install_module(target.loc.mod_path, replacement);
        assert solver.placement_work(prog) is work;
        assert dependent_edges <= work.pending;
        assert id(target) not in work.modules;
        assert id(target) not in work.references;
    } finally {
        work.solving = False;
    }
}

test "invalidating a module removes its reference graph and closure release drops all work" {
    (prog, mod) = _compile();
    work = solver.placement_work(prog);
    work.refs(mod);
    prog.invalidate_module(mod.loc.mod_path);
    assert id(mod) not in work.modules;
    assert id(mod) not in work.references;
    with patch.dict(os.environ, {"JAC_NO_UNIT_EVICT": ""}) {
        prog.release_compile_closure();
    }
    assert prog.analysis.placement_work is None;
}

test "client placement reaches the end of a long import chain" {
    with tempfile.TemporaryDirectory(prefix="jac-placement-chain-") as tmp {
        for i in range(40) {
            source = "def value -> int { return 1; }"
                if i == 39
                else (
                    f"import from m{i + 1} {{ value as next_value }}\n"
                    "def value -> int { return next_value(); }"
                );
            with open(os.path.join(tmp, f"m{i}.jac"), "w") as f {
                f.write(source);
            }
        }
        path = os.path.join(tmp, "app.jac");
        with open(path, "w") as f {
            f.write(
                "import from m0 { value }\ndef app -> JsxElement { return <div>{value()}</div>; }"
            );
        }
        prog = JacProgram();
        mod = prog.compile(path, no_cgen=True);
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        for i in range(40) {
            target = prog.find_module(os.path.join(tmp, f"m{i}.jac"));
            assert target is not None , i;
            ability = next(
                top
                for top in target.body
                if isinstance(top, uni.Ability)
            );
            assert ability.code_context == CodeContext.CLIENT , i;
            assert ability.codespace_dual , i;
        }
        with patch.object(
            solver, "_pull_boundary_import", wraps=solver._pull_boundary_import
        ) as pulls {
            solver.solve_program_placement(mod, prog);
            assert pulls.call_count == 0 , pulls.call_count;
        }
    }
}

test "client placement follows imports inside a function" {
    with tempfile.TemporaryDirectory(prefix="jac-placement-nested-") as tmp {
        helper = os.path.join(tmp, "helper.jac");
        with open(helper, "w") as stream {
            stream.write("def value -> int { return 42; }");
        }
        path = os.path.join(tmp, "app.jac");
        with open(path, "w") as stream {
            stream.write(
                "def app -> JsxElement { import from helper { value } return <div>{value()}</div>; }"
            );
        }
        prog = JacProgram();
        mod = prog.compile(path, no_cgen=True);
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        dependency = prog.find_module(helper);
        assert dependency is not None;
        ability = dependency.get_all_sub_nodes(uni.Ability)[0];
        assert ability.code_context == CodeContext.CLIENT;
        assert ability.codespace_dual;
        assert len(solver.placement_work(prog).owned[id(mod)]) == 1;
    }
}

test "a cyclic import graph converges and remains idle after solving" {
    with tempfile.TemporaryDirectory(prefix="jac-placement-cycle-") as tmp {
        for (name, other) in [("left", "right"), ("right", "left")] {
            with open(os.path.join(tmp, name + ".jac"), "w") as f {
                f.write(
                    f"import from {other} {{ value as next_value }}\n"
                    "def value(n: int) -> int {\n"
                    "    return 1 if n == 0 else next_value(n - 1);\n}"
                );
            }
        }
        path = os.path.join(tmp, "app.jac");
        with open(path, "w") as f {
            f.write(
                "import from left { value }\n"
                "def app -> JsxElement { return <div>{value(4)}</div>; }"
            );
        }
        prog = JacProgram();
        mod = prog.compile(path, no_cgen=True);
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        for name in ["left", "right"] {
            target = prog.find_module(os.path.join(tmp, name + ".jac"));
            assert target is not None;
            ability = next(
                top
                for top in target.body
                if isinstance(top, uni.Ability)
            );
            assert ability.code_context == CodeContext.CLIENT;
        }
        with patch.object(
            solver, "_pull_boundary_import", wraps=solver._pull_boundary_import
        ) as pulls {
            solver.solve_program_placement(mod, prog);
            assert pulls.call_count == 0 , pulls.call_count;
        }
    }
}
