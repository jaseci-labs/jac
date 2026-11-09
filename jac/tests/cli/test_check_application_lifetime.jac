import gc;
import weakref;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import os;
import from jaclang.cli.commands.analysis { check, _shard_units }
import jaclang.compiler.driver.pipeline_runner as pipeline;

test "application checks release their programs between jobs in a reused worker" {
    programs: list[any] = [];
    original = pipeline.compile_application;

    def track(program: any, entry_path: str, options: any) -> any {
        programs.append(weakref.ref(program));
        return original(program, entry_path, options);
    }

    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / 'jac.toml').write_text(
            '[project]\nname="check_lifetime"\n'
                + '[apps.first]\nkind="cli"\nentry-point="first"\n'
                + '[apps.second]\nkind="cli"\nentry-point="second"\n'
        );
        for name in ['first', 'second'] {
            (base / (name + '.jac')).write_text('def answer -> int { return 42; }\n');
        }
        with patch.object(pipeline, 'compile_application', side_effect=track) {
            assert check(paths=[tmp], nowarn=True, jobs='1') == 0;
        }
    }
    assert len(programs) == 2;
    gc.collect();
    assert all(program() is None for program in programs);
}

test "JAC_CHECK_SHARD splits the checked files into disjoint legs that cover them all" {
    with TemporaryDirectory() as tmp {
        units: list[dict[str, str]] = [];
        for (idx, size) in enumerate([50, 400, 10, 900, 200]) {
            path = Path(tmp) / f"m{idx}.jac";
            path.write_text("x" * size);
            units.append({'path': str(path)});
        }
        legs: list[list[str]] = [];
        for k in range(1, 4) {
            with patch.dict(os.environ, {"JAC_CHECK_SHARD": f"{k}/3"}) {
                legs.append([str(unit['path']) for unit in _shard_units(units)]);
            }
        }
        flat = [path for leg in legs for path in leg];
        assert sorted(flat) == sorted(str(unit['path']) for unit in units);
        assert len(set(flat)) == len(flat);
        assert legs[0][0].endswith("m3.jac") and legs[1][0].endswith("m1.jac");
        with patch.dict(os.environ, {"JAC_CHECK_SHARD": ""}) {
            assert _shard_units(units) == units;
        }
        with patch.dict(os.environ, {"JAC_CHECK_SHARD": "4/3"}) {
            assert _shard_units(units) is None;
        }
    }
}
