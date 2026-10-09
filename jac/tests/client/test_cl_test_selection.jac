"""Client selectors must exclude test bodies before they can change shared state."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.testing.cl_test_runner as cl_runner;
import from jaclang.cli.commands { analysis as analysis_cmds }

def selection_fixture(directory: str) -> str {
    project_dir = Path(directory);
    (project_dir / "jac.toml").write_text('[placement.pins]\n"selection" = "client"\n');
    path = project_dir / "selection.jac";
    path.write_text(
        'glob seen: list[str] = [];\n'
        'test "mutator" { seen.append("ran"); }\n'
        'test "target stays clean" {\n'
        '    assert len(seen) == 0, "excluded mutator ran";\n'
        '}\n'
    );
    return str(path);
}

test "client CLI filters exclude bodies with side effects" {
    with TemporaryDirectory() as tmpdir {
        path = selection_fixture(tmpdir);
        jac_test = getattr(analysis_cmds, "test");
        with patch.dict(os.environ, {"JAC_TEST_JOBS": "0"}) {
            for expr in ("target", "target and not mutator", "missing or target") {
                assert jac_test(paths=[path], filter=expr) == 0;
            }
            assert jac_test(paths=[path], test_name="target stays clean") == 0;
        }
    }
}

test "unmatched client selectors never start the harness or backend" {
    with TemporaryDirectory() as tmpdir {
        path = selection_fixture(tmpdir);
        compiled = cl_runner.compile_cl_module(path);
        compiled[2]["@jac/runtime"] = {};
        with patch.object(cl_runner, "compile_cl_module", return_value=compiled), patch.object(
            cl_runner, "_run_harness"
        ) as harness, patch.object(
            cl_runner, "find_server_entry", return_value=None
        ) as find_server, patch.dict(os.environ, {"JAC_TEST_JOBS": "0"}) {
            assert getattr(analysis_cmds, "test")(paths=[path], filter="missing") == 5;
            harness.assert_not_called();
            find_server.assert_not_called();
        }
    }
}

test "client exact names and unfiltered runs keep their behavior" {
    with TemporaryDirectory() as tmpdir {
        path = selection_fixture(tmpdir);
        results = cl_runner.run_cl_test_file(path);
        assert len(results) == 2;
        assert results[0].ok;
        assert not results[1].ok;
        target_name = results[1].name;
        selected = cl_runner.run_cl_test_file(path, test_name=target_name);
        assert len(selected) == 1;
        assert selected[0].ok;
    }
}
