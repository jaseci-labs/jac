"""Placement converges without repeatedly solving an unchanged import graph."""

import os;
import tempfile;
import from unittest.mock { patch }
import from tests.support { JAC_ROOT }
import jaclang.compiler.frontend.unitree as uni;
import jaclang.compiler.placement.placement_solver as solver;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.constant { CodeContext }

def _compile -> tuple[JacProgram, uni.Module] {
    prog = JacProgram();
    path = os.path.join(
        JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "infer_xmod_app.jac"
    );
    mod = prog.compile(path, no_cgen=True);
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    return (prog, mod);
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
    assert "work" not in prog.analysis.placement_state;
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
