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

test "failed precompile retains analysis measurements and a repaired source recovers" {
    import json;
    import os;
    import from unittest.mock { patch }
    import jaclang.dist.precompile_bytecode as pre;
    with TemporaryDirectory() as directory {
        package = Path(directory) / "sample";
        package.mkdir();
        (package / "__init__.jac").write_text("# Package entry.\n");
        (package / "good.jac").write_text("def value() -> int { return 7; }\n");
        broken = package / "broken.jac";
        broken.write_text("def answer() -> int { return 'wrong'; }\n");
        result_path = Path(directory) / "metrics" / "precompile.json";
        with patch.object(pre, "precompile_exit") as leave, patch.dict(
            os.environ,
            {
                "JAC_REBUILD": "0",
                "JAC_NO_PRECOMPILE": "0",
                "JAC_PRECOMPILE_METRICS": str(result_path)
            }
        ) {
            pre.run_precompile(directory, jobs_arg="0");
            assert leave.call_args[0][0] == 1;
            cold = json.loads(result_path.read_text());
            assert cold["complete"];
            assert not (package / "_precompiled/PRECOMPILE_RESULT.json").exists();
            assert cold["failed"] == 1 and cold["compiled"] == 2;
            failed = next(
                result for worker in cold["workers"]
                for result in worker["result"]
                if result["status"] == "failed"
            );
            assert any(
                record.get("parse_runs") and record.get("pass_runs")
                for record in failed.get("analysis", [])
            ) , "the failed module lost its compiler work measurements";
            assert not list((package / "_precompiled").rglob("broken.jir"));
            broken.write_text("def answer() -> int { return 42; }\n");
            pre.run_precompile(directory, jobs_arg="0");
            repaired = json.loads(result_path.read_text());
            assert repaired["complete"];
            assert leave.call_args[0][0] == 0;
            assert repaired["failed"] == 0;
            assert repaired["compiled"] == 1 and repaired["reused"] == 2;
        }
    }
}

test "interface-only dependencies survive fresh caches and retain sealed integrity" {
    import json;
    import os;
    import shutil;
    import sys;
    import from unittest.mock { patch }
    import jaclang.compiler.driver.jir as jir;
    import jaclang.dist.precompile_bootstrap as bootstrap;
    import jaclang.dist.precompile_bytecode as pre;
    import from jaclang.jac0core.sealed { SealedImage }
    with TemporaryDirectory() as directory {
        package = Path(directory) / "jaclang";
        provider = package / "runtime/na_stdlib/provider.jac";
        provider.parent.mkdir(parents=True);
        provider.write_text("def value() -> int { return 7; }\n");
        entry_source = package / "__init__.jac";
        entry_source.write_text(
            "import from .runtime.na_stdlib.provider { value }\n"
            "def answer() -> int { return value(); }\n"
        );
        assert pre.sealable_sources(str(package)) == [str(entry_source)];
        cache = Path(directory) / "source-cache";
        output = package / "_precompiled";
        pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
        interface = output / pyver / "runtime/na_stdlib/provider.jir";
        result_path = Path(directory) / "metrics/precompile.json";
        with patch.object(jir, "_module_cache_root", return_value=cache), patch.object(
            pre, "precompile_exit"
        ) as leave, patch.dict(
            os.environ,
            {
                "JAC_PRECOMPILE_METRICS": str(result_path),
                "JAC_REBUILD": "0",
                "JAC_NO_PRECOMPILE": "0"
            }
        ), patch.object(bootstrap, "bootstrap_sources", return_value=[]), patch.object(
            pre, "bootstrap_sources", return_value=[]
        ) {
            pre.run_precompile(directory, seal_compile=True, jobs_arg="0");
            assert leave.call_args[0][0] == 0;
            cold = json.loads(result_path.read_text());
            assert cold["compiled"] == 1 and cold["interfaces"] == 1;
            data = interface.read_bytes();
            assert jir.read_section_bytes(data, jir.SEC_IFACE) is not None;
            assert jir.read_section_bytes(data, jir.SEC_BYTECODE) is None;
            original = {
                str(p.relative_to(output)): p.read_bytes()
                for p in output.rglob("*.jir")
            };
            shutil.rmtree(cache, ignore_errors=True);
            with pre.precompile_unit_context(str(provider), str(package)) as program {
                executable = pre._precompile_unit(str(provider), str(package), program);
                assert executable is not None;
                bytecode = jir.read_section_bytes(executable, jir.SEC_BYTECODE);
                assert bytecode is not None;
                cached = jir.get_module_cache_path(str(provider));
                cached.unlink(missing_ok=True);
                jir.write_module_cache(str(provider), bytecode);
                assert jir.read_section_bytes(cached.read_bytes(), jir.SEC_IFACE)
                    is None;
            }
            pre.run_precompile(directory, seal_compile=True, jobs_arg="0");
            warm = json.loads(result_path.read_text());
            assert warm["compiled"] == 0 and warm["reused"] == 1;
            assert warm["dependency_plan"]["syntax_parses"] == 0;
            assert all(
                not any(record.get("pass_runs", {}).values())
                    and not any(record.get("parse_runs", {}).values())
                for worker in warm["workers"] for result in worker["result"]
                for record in result.get("analysis", [])
            );
            assert original
                == {
                    str(p.relative_to(output)): p.read_bytes()
                    for p in output.rglob("*.jir")
                };
            for embed_src in [True, False] {
                shutil.rmtree(cache, ignore_errors=True);
                pre.run_precompile(
                    directory, seal_compile=True, jobs_arg="0", embed_src=embed_src
                );
                assert leave.call_args[0][0] == 0;
                rewrapped = json.loads(result_path.read_text());
                assert all(
                    not any(record.get("pass_runs", {}).values())
                        and not any(record.get("parse_runs", {}).values())
                    for worker in rewrapped["workers"] for result in worker["result"]
                    for record in result.get("analysis", [])
                );
                for product in output.rglob("*.jir") {
                    wrapped = product.read_bytes();
                    assert jir.read_section_bytes(wrapped, jir.SEC_IFACE) is not None;
                    assert (jir.read_debug_source(wrapped) is not None) == embed_src;
                }
            }
            assert original
                == {
                    str(p.relative_to(output)): p.read_bytes()
                    for p in output.rglob("*.jir")
                };
            assert pre.seal_finalize(package, output, "jaclang", pyver, False) == 0;
            manifest = json.loads((output / "MANIFEST.json").read_text());
            assert "runtime/na_stdlib/provider.jac" not in manifest["modules"];
            assert interface.relative_to(package).as_posix() in manifest["payloads"];
            image = SealedImage(output, manifest);
            assert image.find("jaclang.runtime.na_stdlib.provider") is None;
            image.verify();
            interface.write_bytes(b"damaged interface");
            rejected = False;
            try {
                image.verify();
            } except RuntimeError {
                rejected = True;
            } finally {
                interface.write_bytes(data);
            }
            assert rejected , "the seal did not validate its interface payload";
            provider.unlink();
            assert pre.seal_finalize(package, output, "jaclang", pyver, False) == 1;
            provider.write_text("def value() -> str { return 'changed'; }\n");
            assert pre.seal_finalize(package, output, "jaclang", pyver, False) == 1;
            (output / "MANIFEST.json").unlink();
            shutil.rmtree(cache, ignore_errors=True);
            pre.run_precompile(directory, seal_compile=True, jobs_arg="0");
            assert leave.call_args[0][0] == 1;
            assert json.loads(result_path.read_text())["failed"] == 1;
        }
    }
}

test "interrupted precompile checkpoints completed jobs as an unfinished report" {
    import json;
    import os;
    import from unittest.mock { patch }
    import from jaclang.cli.workpool { WorkPool }
    import jaclang.dist.precompile_bytecode as pre;
    with TemporaryDirectory() as directory {
        package = Path(directory) / "sample";
        package.mkdir();
        (package / "__init__.jac").write_text("# Package entry.\n");
        (package / "value.jac").write_text("def value() -> int { return 7; }\n");
        result_path = Path(directory) / "metrics/precompile.json";
        interrupted = False;
        with patch.object(
            WorkPool, "_should_stop", side_effect=[False, KeyboardInterrupt()]
        ), patch.dict(os.environ, {"JAC_PRECOMPILE_METRICS": str(result_path)}) {
            try {
                pre.run_precompile(directory, jobs_arg="0");
            } except KeyboardInterrupt {
                interrupted = True;
            }
        }
        assert interrupted;
        saved = json.loads(result_path.read_text());
        assert not saved["complete"];
        assert saved["compiled"] == 1 and saved["total"] == 2;
        assert len(saved["workers"]) == 1;
        assert saved["workers"][0]["result"][0]["status"] == "compiled";
        assert saved["dependency_plan"]["modules"] == 2;
        assert not (package / "_precompiled/PRECOMPILE_RESULT.json").exists();
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
        result_path = Path(directory) / "precompile.json";
        with patch.object(pre, "precompile_exit") as leave, patch.dict(
            os.environ,
            {
                "JAC_PRECOMPILE_RECYCLE": "1",
                "JAC_PRECOMPILE_METRICS": str(result_path),
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
