import from concurrent.futures { ThreadPoolExecutor }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from threading { Barrier }
import from jaclang.project.config {
    config_scope,
    config_state,
    get_config,
    set_config,
    JacConfig
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context { SourceStore }

test "configuration scopes isolate project selection across compiler threads" {
    saved = config_state();
    with TemporaryDirectory() as directory {
        base = Path(directory);
        for (name, memory) in [('first', 'rc'), ('second', 'managed')] {
            project = base / name;
            project.mkdir();
            (project / 'jac.toml').write_text(
                f'[project]\nname="{name}"\n[memory]\nprofile="{memory}"\n'
            );
        }
        barrier = Barrier(2);
        def inspect(name: str) -> tuple[str, str | None] {
            with config_scope(base / name) {
                barrier.wait(timeout=10);
                config = get_config();
                assert config is not None;
                return (config.project.name, CompileOptions().memory_profile);
            }
        }
        with ThreadPoolExecutor(max_workers=2) as executor {
            first = executor.submit(inspect, 'first');
            second = executor.submit(inspect, 'second');
            assert first.result() == ('first', 'rc');
            assert second.result() == ('second', 'managed');
        }
    }
    assert config_state() is saved;
    with config_scope() as outer {
        set_config(JacConfig());
        try {
            with config_scope() as inner {
                assert inner is not outer and not inner.explicit;
                raise RuntimeError('scope abandoned');
            }
        } except RuntimeError {}
        assert config_state() is outer and outer.explicit;
    }
    assert config_state() is saved;
}

test "configuration reads share the compiler source snapshot and refresh after edits" {
    with TemporaryDirectory() as directory {
        project = Path(directory);
        config = project / 'jac.toml';
        overlay = project / 'jac.local.toml';
        config.write_text('[project]\nname="before"\n');
        store = SourceStore();
        with store.capture() as inputs {
            with config_scope(project) {
                first = get_config();
                assert first is not None and first.project.name == 'before';
                config.write_text('[project]\nname="after!"\n');
                second = get_config(force_discover=True);
                assert second is not None and second.project.name == 'before';
                assert not inputs.is_current(store);
            }
        }
        with store.capture() as inputs {
            with config_scope(project) {
                fresh = get_config();
                assert fresh is not None and fresh.project.name == 'after!';
                assert inputs.is_current(store);
                overlay.write_text('[memory]\nprofile="rc"\n');
                assert not inputs.is_current(store);
            }
        }
        with config_scope(project) {
            assert CompileOptions().memory_profile == 'rc';
        }
    }
}
