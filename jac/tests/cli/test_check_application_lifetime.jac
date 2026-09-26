import gc;
import weakref;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.cli.commands.analysis { check }
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
