"""Packaging workers reclaim released graphs within their scheduling budget."""

import gc;
import os;
import subprocess;
import sys;
import weakref;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.cli.workpool as pool;
import jaclang.dist.precompile_bytecode as packaging;
import from jaclang.dist.precompile_bytecode {
    _precompile_retire,
    _shard_sources,
    run_precompile
}

obj ReleasedCycle {
    has next: ReleasedCycle | None = None;
}

def released_cycle -> weakref.ReferenceType[ReleasedCycle] {
    item = ReleasedCycle();
    item.next = item;
    return weakref.ref(item);
}

test "precompile reclaims released cycles and keeps a worker that fits" {
    before = released_cycle();
    with patch.dict(
        os.environ, {"JAC_PRECOMPILE_RECYCLE": "0", "JAC_PRECOMPILE_RECYCLE_MB": "2048"}
    ), patch.object(pool, "worker_rss_mb", return_value=512), patch.object(
        pool, "maybe_malloc_trim"
    ) {
        assert not _precompile_retire(3, 2300);
    }
    assert before() is None;
}

test "precompile retires when live memory still exceeds its budget" {
    with patch.dict(
        os.environ, {"JAC_PRECOMPILE_RECYCLE": "0", "JAC_PRECOMPILE_RECYCLE_MB": "2048"}
    ), patch.object(pool, "worker_rss_mb", return_value=2200), patch.object(
        pool, "maybe_malloc_trim"
    ) {
        assert _precompile_retire(3, 2300);
    }
}

test "precompile respects explicit recycling and disabled memory limits" {
    with patch.object(gc, "collect") as collect {
        with patch.dict(
            os.environ,
            {"JAC_PRECOMPILE_RECYCLE": "2", "JAC_PRECOMPILE_RECYCLE_MB": "2048"}
        ) {
            assert _precompile_retire(2, 2300);
        }
        with patch.dict(
            os.environ,
            {"JAC_PRECOMPILE_RECYCLE": "0", "JAC_PRECOMPILE_RECYCLE_MB": "0"}
        ) {
            assert not _precompile_retire(20, 8192);
        }
        collect.assert_not_called();
    }
}

test "macOS worker memory reflects the current resident set" {
    with patch.object(sys, "platform", "darwin"), patch.object(
        subprocess, "check_output", side_effect=["  2097152\n", "  524288\n"]
    ) {
        assert pool.worker_rss_mb() == 2048;
        assert pool.worker_rss_mb() == 512;
    }
}

test "precompile sizes auto workers for its configured memory ceiling" {
    with TemporaryDirectory() as directory {
        package = Path(directory) / "library";
        package.mkdir();
        (package / "__init__.jac").write_text("");
        with patch.dict(os.environ, {"JAC_PRECOMPILE_RECYCLE_MB": "4096"}), patch.object(
            pool, "resolve_jobs", side_effect=InterruptedError
        ) as resolve {
            interrupted = False;
            try {
                run_precompile(directory, jobs_arg="auto");
            } except InterruptedError {
                interrupted = True;
            }
            assert interrupted;
            budget = resolve.call_args.kwargs.get("worker_bytes", 0);
            assert budget == 4096 * 1024 * 1024;
            assert pool.default_jobs(worker_bytes=budget, avail_bytes=16 * 1024 ** 3)
                <= 2;
        }
    }
}

test "precompile publishes bytecode and interfaces across memory reclamation" {
    import from jaclang.compiler.driver.jir {
        SEC_BYTECODE,
        SEC_IFACE,
        read_section_bytes
    }
    if not pool.pool_available() {
        testskip("worker reclamation requires fork");
    }
    with TemporaryDirectory() as directory {
        package = Path(directory) / "library";
        package.mkdir();
        (package / "__init__.jac").write_text("glob version: int = 1;\n");
        (package / "model.jac").write_text("obj Box { has value: int; }\n");
        (package / "api.jac").write_text(
            "import from .model { Box }\ndef make() -> Box { return Box(42); }\n"
        );
        (package / "jac.toml").write_text(
            '[project]\nname = "library"\n[placement]\ndefault = "server"\n'
        );
        with patch.dict(
            os.environ,
            {"JAC_PRECOMPILE_RECYCLE": "0", "JAC_PRECOMPILE_RECYCLE_MB": "1"}
        ), patch.object(packaging, "precompile_exit") as finish {
            run_precompile(directory, jobs_arg="2");
            finish.assert_called_once_with(0);
        }
        outputs = list((package / "_precompiled").rglob("*.jir"));
        assert len(outputs) == 3;
        for output in outputs {
            data = output.read_bytes();
            assert read_section_bytes(data, SEC_BYTECODE) is not None;
            assert read_section_bytes(data, SEC_IFACE) is not None , str(output);
        }
    }
}

test "precompile shards split the sources largest first and cover them once" {
    with TemporaryDirectory() as td {
        files: list[str] = [];
        for (name, size) in [("a", 50), ("b", 10), ("c", 40), ("d", 30), ("e", 20)] {
            path = os.path.join(td, f"{name}.jac");
            with open(path, "w") as f {
                f.write("x" * size);
            }
            files.append(path);
        }
        shards: list[list[str]] = [];
        for k in (1, 2) {
            with patch.dict(os.environ, {"JAC_PRECOMPILE_SHARD": f"{k}/2"}) {
                shard = _shard_sources(files);
                assert shard is not None;
                shards.append(shard);
            }
        }
        names = [[os.path.basename(p)[0] for p in shard] for shard in shards];
        assert names == [["a", "d", "b"], ["c", "e"]] , names;
        with patch.dict(os.environ, {"JAC_PRECOMPILE_SHARD": "3/2"}) {
            assert _shard_sources(files) is None;
        }
        with patch.dict(os.environ, {"JAC_PRECOMPILE_SHARD": ""}) {
            assert _shard_sources(files) == files;
        }
    }
}
