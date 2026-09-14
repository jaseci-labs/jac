import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.dependency_graph { dependency_groups }
import from jaclang.compiler.driver.compilation_context { CompilationSession }
import from jaclang.dist.precompile_plan { plan_precompile }
import from jaclang.dist.precompile_bytecode { precompile_context }

test "cycle members are separate retirement points behind a dependency barrier" {
    import from jaclang.dist.precompile_plan { PrecompilePlan }
    import from jaclang.compiler.driver.compilation_context { SourceStore }
    import from jaclang.cli.workpool { WorkPool }
    plan = PrecompilePlan(
        groups=[["dependency"], ["cycle_a", "cycle_b"], ["consumer"]],
        prerequisites={0: set(), 1: {0}, 2: {1}},
        sources=SourceStore(),
        measurements={}
    );
    (paths, prerequisites) = plan.work_queue();
    finished: list[str] = [];
    def job(request: dict[str, any]) -> str {
        path = str(request["path"]);
        if path == "cycle_a" {
            raise RuntimeError("the first member failed");
        }
        return path;
    }
    def record(index: int, result: dict[str, any]) {
        finished.append(paths[index]);
        if paths[index] == "cycle_a" {
            assert "the first member failed" in result["error"];
        } else {
            assert result["result"] == paths[index];
        }
    }
    WorkPool(
        items=paths, prerequisites=prerequisites, job=job, on_record=record
    ).run_inline();
    assert finished == ["dependency", "cycle_a", "cycle_b", "consumer"];
}

test "dependency groups are deterministic and keep import cycles together" {
    edges = {
        "root": ["right", "left"],
        "right": ["shared"],
        "left": ["shared"],
        "shared": ["cycle"],
        "cycle": ["shared"]
    };
    groups = dependency_groups(edges, ["root"]);
    assert groups[0] == ["cycle", "shared"];
    assert groups[-1] == ["root"];
    assert groups
        == dependency_groups(dict(reversed(list(edges.items()))), ["root", "root"]);
    chain = {str(i): [str(i + 1)] for i in range(1500)};
    ordered = dependency_groups(chain, ["0"]);
    assert len(ordered) == 1501;
    assert ordered[0] == ["1500"];
    assert ordered[-1] == ["0"];
}

test "package planning shares pristine syntax and resolves imports from annexes" {
    with TemporaryDirectory() as directory {
        package_path = Path(directory);
        shared = package_path / "shared.jac";
        shared.write_text("def value() -> int { return 42; }\n");
        left = package_path / "left.jac";
        left.write_text(
            "import from shared { value }\ndef answer() -> int { return value(); }\n"
        );
        right = package_path / "right.jac";
        right.write_text("def answer() -> int;\n");
        (package_path / "right.impl.jac").write_text(
            "import from shared { value }\nimpl answer { return value(); }\n"
        );
        plan = plan_precompile([str(left), str(right)], directory);
        owners = {
            path: idx for (idx, members) in enumerate(plan.groups) for path in members
        };
        assert plan.prerequisites[owners[str(left)]] == {owners[str(shared)]};
        assert plan.prerequisites[owners[str(right)]] == {owners[str(shared)]};
        assert plan.sources.parses == 3;
        with CompilationSession() as session {
            session.program.source_store = plan.sources;
            program = precompile_context(str(left), directory, session.program);
            planned = plan.sources.units[plan.sources.revisions[str(left)]].syntax;
            compiled = program._get_compiler().parse_str(
                left.read_text(), str(left), program
            );
            assert compiled is planned;
            assert str(left) not in plan.sources.revisions;
            assert plan.sources.parses == 3;
            assert plan.sources.hits == 1;
        }
    }
}

test "dependency discovery does not populate descendant indexes on pristine syntax" {
    import from unittest.mock { patch }
    import jaclang.compiler.frontend.unitree as uni;
    with TemporaryDirectory() as directory, CompilationSession() as session {
        target = Path(directory) / "shared.jac";
        target.write_text("def value() -> int { return 42; }\n");
        path = str(Path(directory) / "main.jac");
        unit = session.program.source_store.load(
            "import from shared { value }\ndef answer() -> int { return value(); }\n",
            path,
            session.program,
            []
        );
        with patch.object(
            uni.UniNode,
            "_construct_sub_node_tab",
            side_effect=AssertionError("dependency discovery built descendant indexes")
        ) {
            session.program.deps.record_module(unit.syntax);
        }
        assert session.program.deps.dependencies[path] == {str(target)};
    }
}

test "package precompile coordinates a diamond and cycles through warm and edited builds" {
    import json;
    import os;
    import shutil;
    import sys;
    import from unittest.mock { patch }
    import jaclang.dist.precompile_bytecode as pre;
    with TemporaryDirectory() as directory {
        package_path = Path(directory) / "sample";
        package_path.mkdir();
        (package_path / "__init__.jac").write_text("# Package entry.\n");
        (package_path / "shared.jac").write_text("def value() -> int { return 42; }\n");
        for name in ["left", "right"] {
            (package_path / (name + ".jac")).write_text(
                "import from shared { value }\ndef answer() -> int { return value(); }\n"
            );
        }
        (package_path / "cycle_a.jac").write_text(
            "import from cycle_b { second }\ndef first() -> int { return second(); }\n"
        );
        (package_path / "cycle_b.jac").write_text(
            "import from cycle_a { first }\ndef second() -> int { return 7; }\n"
        );
        result_path = package_path / "_precompiled" / pre.RESULT_NAME;
        with patch.object(pre, "precompile_exit") as leave, patch.dict(
            os.environ,
            {
                "JAC_PRECOMPILE_RECYCLE": "1",
                "JAC_REBUILD": "0",
                "JAC_NO_PRECOMPILE": "0"
            }
        ) {
            pre.run_precompile(directory, jobs_arg="2");
            assert leave.call_args[0][0] == 0;
            cold = json.loads(result_path.read_text());
            assert cold["compiled"] == 6;
            assert cold["failed"] == 0;
            assert cold["dependency_plan"]["groups"] == 5;
            assert len(cold["workers"]) == 6;
            assert all(len(worker["result"]) == 1 for worker in cold["workers"]);
            if hasattr(os, "fork") {
                assert all(worker["served"] == 1 for worker in cold["workers"]);
                assert len({worker["worker_pid"] for worker in cold["workers"]}) == 6;
            }
            before = {
                path.name: path.read_bytes()
                for path in (package_path / "_precompiled").rglob("*.jir")
            };
            shutil.rmtree(package_path / ".jac", ignore_errors=True);
            pre.run_precompile(directory, jobs_arg="2");
            warm = json.loads(result_path.read_text());
            assert warm["compiled"] == 0;
            assert warm["reused"] == 6;
            assert warm["dependency_plan"]["syntax_parses"] == 0;
            assert warm["dependency_plan"]["dependency_hits"] == 6;
            assert before
                == {
                    path.name: path.read_bytes()
                    for path in (package_path / "_precompiled").rglob("*.jir")
                };
            (package_path / "shared.jac").write_text(
                "def value() -> int { return 43; }\n"
            );
            pre.run_precompile(directory, jobs_arg="0");
            edited = json.loads(result_path.read_text());
            assert edited["failed"] == 0;
            assert edited["compiled"] == 1;
            assert edited["reused"] == 5;
            with patch.dict(os.environ, {"JAC_REBUILD": "1"}) {
                pre.run_precompile(directory, jobs_arg="0");
                forced = json.loads(result_path.read_text());
                assert forced["failed"] == 0;
                assert forced["compiled"] == 6;
                assert forced["reused"] == 0;
            }
            with patch.dict(os.environ, {"JAC_NO_PRECOMPILE": "1"}) {
                pre.run_precompile(directory, jobs_arg="0");
                bypassed = json.loads(result_path.read_text());
                assert bypassed["failed"] == 0;
                assert bypassed["reused"] == 0;
            }
        }
    }
}
