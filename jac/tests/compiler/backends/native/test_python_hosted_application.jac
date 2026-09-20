"""Hosted native entries use sealed native payloads and preserve Python failures."""
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pipeline_runner { native_application }
import from jaclang.dist.native_application { write_native_image }
import from jaclang.dist.seal { tar_gz_dir }


def build_image(name: str, directory: Path) {
    program = JacProgram();
    (module, _) = native_application(program, str(Path(NATIVE_FIXTURES) / name));
    assert not program.errors_had , str(program.errors_had);
    assert module is not None;
    write_native_image(module, directory);
}


test "sealed native application runs with bundled Python and argv" {
    with tempfile.TemporaryDirectory() as work {
        image = Path(work) / "image";
        build_image("python_application_entry.jac", image);
        bundle = Path(work) / "app.jab";
        bundle.write_bytes(tar_gz_dir(image));
        result = subprocess.run(
            jac_command("run", str(bundle), "--", "hello"),
            text=True,
            capture_output=True,
            timeout=180
        );
        assert result.returncode == 0 , result.stdout + result.stderr;
        assert result.stdout.splitlines()[-3:] == ['{"value": 42}', "b.txt", "hello"];
    }
}


test "sealed native application preserves entry point Python exceptions" {
    import math;
    import from jaclang.dist.jab { jab_app_meta }
    import from jaclang.dist.native_application { run_native_application }
    expected = "";
    try {
        math.sqrt(-1.0);
    } except ValueError as error {
        expected = str(error);
    }
    assert expected;
    with tempfile.TemporaryDirectory() as work {
        image = Path(work) / "image";
        build_image("python_hosted_error.jac", image);
        meta = jab_app_meta(image);
        caught = False;
        try {
            run_native_application(str(image / meta["entry"]["path"]), []);
        } except ValueError as error {
            caught = True;
            assert str(error) == expected , repr(error);
        }
        assert caught , "native entry returned without propagating ValueError";
    }
}


test "project native payloads share the hosted artifact and entry metadata" {
    import shutil;
    import from jaclang.project.config { get_config_for_path }
    import from jaclang.dist.seal { bake_native_payloads }
    import from jaclang.dist.precompile_bytecode { app_metadata }
    with tempfile.TemporaryDirectory() as work {
        project = Path(work) / "project";
        project.mkdir();
        (project / "jac.toml").write_text(
            '[project]\nname = "hosted_project"\nversion = "1.0.0"\n'
            '[apps.main]\nkind = "cli-native"\nentry-point = "main"\n'
        );
        shutil.copyfile(
            Path(NATIVE_FIXTURES) / "python_application_entry.jac", project / "main.jac"
        );
        config = get_config_for_path(project);
        assert config is not None;
        image = Path(work) / "image";
        shutil.copytree(project, image);
        assert bake_native_payloads(config, image, "main");
        meta = app_metadata(image, "hosted_project", "main");
        assert meta["entry"]["runtime"] == "native-shared";
        assert meta["entry"]["path"].endswith("/main.so");
        assert (image / meta["entry"]["path"]).is_file();
    }
}


test "rebuilding a fused application replaces its existing application overlay" {
    import hashlib;
    import from jaclang.dist.fused_binary { append_overlay, fused_base_length }
    import from jaclang.dist.fused.trailer {
        MAGIC,
        OVERLAY_MAGIC,
        TRAILER_LEN,
        build_trailer,
        parse_trailer
    }
    with tempfile.TemporaryDirectory() as work {
        directory = Path(work);
        runtime = b"runtime";
        base = directory / "jac";
        original = b"launcher"
            + runtime
            + build_trailer(MAGIC, len(runtime), hashlib.sha256(runtime).hexdigest());
        base.write_bytes(original);
        bundle = directory / "app.jab";
        bundle.write_bytes(b"first");
        first = directory / "first";
        assert append_overlay(str(base), str(bundle), str(first));
        bundle.write_bytes(b"second");
        second = directory / "second";
        assert append_overlay(str(first), str(bundle), str(second));
        data = second.read_bytes();
        assert fused_base_length(data) == len(original);
        assert data[:-TRAILER_LEN] == original + b"second";
        trailer = parse_trailer(data[-TRAILER_LEN:], OVERLAY_MAGIC);
        assert trailer is not None and trailer.payload_len == len(b"second");
    }
}
