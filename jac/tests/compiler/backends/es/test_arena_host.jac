import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.client.bun_installer { get_bun }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.project.config { JacConfig, get_config, set_config }

test "arena host scalar boundary input and asynchronous lifecycle" {
    source = Path(TESTS_DIR).parent
        / "examples"
        / "jaclang_org"
        / "core"
        / "site"
        / "game"
        / "webgl_host.jac";
    previous = get_config();
    try {
        set_config(JacConfig.discover(start_path=source.parent));
        program = JacProgram();
        module = program.compile(
            str(source), options=CompileOptions(force_target_program=True)
        );
        assert not program.errors_had , str(program.errors_had);
        js = module.gen.js;
        webgl = program.compile(
            str(Path(TESTS_DIR).parent / "jaclang" / "client" / "webgl.jac"),
            options=CompileOptions(force_target_program=True)
        );
        assert not program.errors_had , str(program.errors_had);
        webgl_js = webgl.gen.js;
    } finally {
        set_config(previous);
    }
    runtime = get_bun();
    assert runtime is not None;
    fixtures = Path(TESTS_DIR) / "compiler" / "backends" / "es" / "fixtures";
    with tempfile.TemporaryDirectory() as tmp {
        target = Path(tmp);
        (target / "host.mjs").write_text(
            js.replace("@jac/wasm_host", "./wasm_host.mjs").replace(
                "@jac/webgl", "./webgl.mjs"
            )
        );
        (target / "webgl.mjs").write_text(webgl_js);
        (target / "wasm_host.mjs").write_text(
            (fixtures / "arena_wasm_stub.mjs").read_text()
        );
        (target / "run.mjs").write_text(
            (fixtures / "arena_host_harness.mjs").read_text()
        );
        result = subprocess.run(
            [runtime, str(target / "run.mjs")],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , result.stderr;
        assert result.stdout.strip() == "arena host checks passed";
    }
}
