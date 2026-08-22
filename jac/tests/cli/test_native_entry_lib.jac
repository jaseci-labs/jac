"""Tests for sealed native entry-library loading helpers and init ordering."""

import os;
import sys;
import json;
import shutil;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from tests.support { TESTS_DIR }
import from jaclang.cli.commands { execution as exec_cmds }
import from jaclang.cli.commands { project as proj_cmds }
import from jaclang.cli.commands.nacompile { nacompile }
import from jaclang.project.config { JacConfig }
import from jaclang.runtimelib.sealed_serve {
    native_lib_name,
    native_lib_suffix,
    NATIVE_DIR_REL
}


def _llvm_available -> bool {
    try {
        import jaclang.compiler.passes.native.llvm.binding as llvm;
        llvm.get_default_triple();
        return True;
    } except Exception {
        return False;
    }
}


def _seal_fixture_project(
    proj_root: Path, name: str, interop: bool = False
) -> JacConfig {
    if interop {
        (proj_root / "helper.jac").write_text(
            "def:pub py_double(x: int) -> int {\n" "    return x * 2;\n" "}\n",
            encoding="utf-8"
        );
        (proj_root / "main.jac").write_text(
            "import from .helper { py_double }\n\n"
            "with entry {\n"
            "    print(py_double(21));\n"
            "}\n",
            encoding="utf-8"
        );
        pins = '\n[placement.pins]\nmain = "native"\nhelper = "server"\n';
    } else {
        (proj_root / "main.jac").write_text("with entry { }\n", encoding="utf-8");
        pins = "";
    }
    (proj_root / "jac.toml").write_text(
        f'[project]\nname = "{name}"\nversion = "0.1.0"\n'
            + f'entry-point = "main.jac"\nkind = "cli-native"\n{pins}',
        encoding="utf-8"
    );
    return JacConfig.load(proj_root / "jac.toml");
}


test "_build_c_argv returns argc and keeps encoded argv pointers" {
    argv = ["/tmp/app.jac", "hello", "world"];
    (argc, c_argv, c_strings) = exec_cmds._build_c_argv(argv);
    assert argc == 3 , f"expected argc 3, got {argc}";
    assert len(c_strings) == 3 , "one c_char_p per argument";
    assert c_strings[0].value == b"/tmp/app.jac" , "argv strings must be UTF-8 encoded";
}


test "native_lib_name appends the platform shared-library suffix" {
    stem = "main";
    assert native_lib_name(stem) == stem + native_lib_suffix();
}


test "_jab_native_lib resolves the sealed native artifact path" {
    import jaclang.compiler.passes.native.llvm.binding as llvm;
    try {
        triple = llvm.get_default_triple();
    } except Exception {
        return;
    }
    with tempfile.TemporaryDirectory() as d {
        img = Path(d);
        entry_rel = "src/main.jac";
        stem = "main";
        native_dir = img / NATIVE_DIR_REL / triple;
        native_dir.mkdir(parents=True);
        lib_path = native_dir / native_lib_name(stem);
        lib_path.write_text("stub", encoding="utf-8");
        found = exec_cmds._jab_native_lib(img, entry_rel);
        assert found == str(lib_path) , f"expected {lib_path}, got {found}";
    }
}


test "_run_native_lib returns None when the library cannot be loaded" {
    rc = exec_cmds._run_native_lib("/no/such/lib.so", ["app.jac"]);
    assert rc is None , "load failure must fall back to the standalone binary";
}


test "_run_native_lib returns None when required exports are missing" {
    class _StubLib {
        def __jac_shared_init(self: _StubLib) { }
    }
    stub = _StubLib();
    with patch("ctypes.CDLL", return_value=stub), patch.object(
        exec_cmds, "_set_native_argv_in_dll", return_value=True
    ) {
        rc = exec_cmds._run_native_lib("fake.so", ["app.jac"]);
    }
    assert rc is None , "missing jac_entry must fall back, not abort the jab run";
}


test "entry_lib runs __jac_shared_init only after argv is populated (Linux)" {
    if not sys.platform.startswith("linux") {
        return;
    }
    import ctypes;
    fixture = os.path.join(
        TESTS_DIR, "compiler", "passes", "native", "fixtures", "entry_lib_argv_init.jac"
    );
    with tempfile.TemporaryDirectory() as d {
        lib_out = os.path.join(d, "entry.so");
        rc = nacompile(filename=fixture, output=lib_out, entry_lib=True);
        assert rc == 0 , "entry_lib nacompile failed";
        assert os.path.isfile(lib_out) , "entry library was not produced";
        host_argv = ["/sealed/main.jac", "alpha", "beta"];
        lib = ctypes.CDLL(lib_out);
        exec_cmds._set_native_argv_in_dll(lib, host_argv);
        shared_init = lib.__jac_shared_init;
        shared_init.restype = None;
        shared_init.argtypes = [];
        shared_init();
        lib.get_captured_argc.restype = ctypes.c_int64;
        captured = int(lib.get_captured_argc());
        assert captured == len(host_argv) , (
            f"glob init saw argc={captured}, expected {len(host_argv)} "
            "(init ran before argv was set)"
        );
    }
}


test "_run_native_lib succeeds for a valid entry library (Linux)" {
    if not sys.platform.startswith("linux") {
        return;
    }
    fixture = os.path.join(
        TESTS_DIR, "compiler", "passes", "native", "fixtures", "entry_lib_argv_init.jac"
    );
    with tempfile.TemporaryDirectory() as d {
        lib_out = os.path.join(d, "entry.so");
        assert nacompile(filename=fixture, output=lib_out, entry_lib=True) == 0;
        host_argv = ["/sealed/main.jac"];
        rc = exec_cmds._run_native_lib(lib_out, host_argv);
        assert rc == 0 , "_run_native_lib should run jac_entry successfully";
    }
}


test "_bake_native_payloads accepts nacompile_sealed_pair success (return 0)" {
    if not _llvm_available() {
        return;
    }
    tmp = tempfile.mkdtemp(prefix="jac_native_seal_");
    try {
        project_dir = Path(tmp) / "proj";
        project_dir.mkdir();
        config = _seal_fixture_project(project_dir, "sealtest");
        pkg_copy = Path(tmp) / "stage";
        pkg_copy.mkdir();
        with patch(
            "jaclang.cli.commands.nacompile.nacompile_sealed_pair", return_value=0
        ) as mock_pair {
            ok = proj_cmds._bake_native_payloads(config, pkg_copy);
        }
        assert ok , (
            "return 0 from nacompile_sealed_pair must not abort native bake "
            "(Jac treats 0 as falsy — check != 0, not `if not`)"
        );
        assert mock_pair.called , "expected nacompile_sealed_pair to be invoked";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "_bake_native_payloads fails when nacompile_sealed_pair returns non-zero" {
    if not _llvm_available() {
        return;
    }
    tmp = tempfile.mkdtemp(prefix="jac_native_seal_");
    try {
        project_dir = Path(tmp) / "proj";
        project_dir.mkdir();
        config = _seal_fixture_project(project_dir, "sealtest");
        pkg_copy = Path(tmp) / "stage";
        pkg_copy.mkdir();
        with patch(
            "jaclang.cli.commands.nacompile.nacompile_sealed_pair", return_value=1
        ) {
            ok = proj_cmds._bake_native_payloads(config, pkg_copy);
        }
        assert not ok , "non-zero nacompile_sealed_pair must abort native bake";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "sealed pair on a native_imports app drops the exe and keeps the lib" {
    if not sys.platform.startswith("linux") {
        return;
    }
    if not _llvm_available() {
        return;
    }
    tmp = tempfile.mkdtemp(prefix="jac_interop_seal_");
    try {
        proj = Path(tmp) / "proj";
        proj.mkdir();
        _seal_fixture_project(proj, "interopseal", interop=True);
        exe_out = str(proj / "main");
        import from jaclang.cli.commands.nacompile { nacompile_sealed_pair }
        rc = nacompile_sealed_pair(
            filename=str(proj / "main.jac"),
            exe_output=exe_out,
            lib_output=str(proj / "libmain.entry.so")
        );
        assert rc == 0 , "interop app must still seal (lib-only), not fail";
        assert os.path.isfile(str(proj / "libmain.entry.so")) , (
            "the host-driven entry library must be sealed"
        );
        assert not os.path.isfile(exe_out) , (
            "the standalone exe cannot exist for native_imports code"
        );
        record = proj / "libmain.entry.so.interop.json";
        assert record.is_file() , (
            "the seal must record the interop decision next to the library"
        );
        rec = json.loads(record.read_text(encoding="utf-8"));
        assert rec.get("interop") is True , "the record must mark the app interop";
        assert rec.get("unresolved") == ["py_double"] , (
            f"the record must name the na->sv bindings; got {rec.get('unresolved')}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "standalone exe nacompile still rejects native_imports" {
    if not _llvm_available() {
        return;
    }
    tmp = tempfile.mkdtemp(prefix="jac_interop_gate_");
    try {
        proj = Path(tmp) / "proj";
        proj.mkdir();
        _seal_fixture_project(proj, "interopseal", interop=True);
        rc = nacompile(filename=str(proj / "main.jac"), output=str(proj / "blocked"));
        assert rc == 1 , "exe target must hard-error on native_imports";
        assert not os.path.isfile(str(proj / "blocked")) , (
            "no artifact may be produced when the gate fires"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


def _fake_jab_image(img_root: Path, interop: bool) {
    import json;
    pre = img_root / "_precompiled";
    pre.mkdir(parents=True, exist_ok=True);
    meta = {
        "kind": "cli-native",
        "capabilities": ["has-entry", "has-native"],
        "entry": {"module": "app.main", "path": "main.jac"},
        "package": "app",
        "native": {"interop": interop}
    };
    (pre / "MANIFEST.json").write_text(json.dumps(meta), encoding="utf-8");
    (img_root / "main.jac").write_text("with entry { }\n", encoding="utf-8");
}


test "run_jab_image execs the sealed exe first when the app is not interop" {
    tmp = tempfile.mkdtemp(prefix="jac_dispatch_exe_");
    try {
        img = Path(tmp) / "img";
        img.mkdir();
        _fake_jab_image(img, interop=False);
        exec_calls: list = [];
        lib_calls: list = [];

        def fake_execv(path: str, argv: list) {
            exec_calls.append((path, list(argv)));
            raise SystemExit(7);
        }

        def fake_run_lib(lib_path: str, argv: list) -> (int | None) {
            lib_calls.append(lib_path);
            return 0;
        }

        with patch(
            "jaclang.cli.commands.execution._jab_native_bin",
            return_value=str(img / "bin")
        ), patch(
            "jaclang.cli.commands.execution._jab_native_lib",
            return_value=str(img / "lib")
        ), patch("jaclang.cli.commands.execution._run_native_lib", fake_run_lib), patch(
            "os.execv", fake_execv
        ) {
            exited = None;
            try {
                exec_cmds.run_jab_image(img, None, ["arg1"], False, "img");
            } except SystemExit as e {
                exited = e.code;
            }
            assert exited == 7 , "the exe rung must execv and replace";
            assert len(exec_calls) == 1 , "execv runs exactly once";
            assert exec_calls[0][0] == str(img / "bin") , (
                "execv targets the sealed exe, not the lib"
            );
            assert "arg1" in exec_calls[0][1] , "args pass through";
            assert lib_calls == [] , (
                "a self-contained exe replaces the process before " "any dlopen rung"
            );
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "run_jab_image stays host-driven when the manifest says interop" {
    tmp = tempfile.mkdtemp(prefix="jac_dispatch_host_");
    try {
        img = Path(tmp) / "img";
        img.mkdir();
        _fake_jab_image(img, interop=True);
        exec_calls: list = [];
        lib_calls: list = [];
        run_calls: list = [];

        def fake_execv(path: str, argv: list) {
            exec_calls.append(path);
            raise SystemExit(7);
        }

        def fake_run_lib(lib_path: str, argv: list) -> (int | None) {
            lib_calls.append(lib_path);
            return 0;
        }

        def fake_run(filename: str, args: list) -> int {
            run_calls.append(filename);
            return 0;
        }

        with patch(
            "jaclang.cli.commands.execution._jab_native_bin",
            return_value=str(img / "bin")
        ), patch(
            "jaclang.cli.commands.execution._jab_native_lib",
            return_value=str(img / "lib")
        ), patch("jaclang.cli.commands.execution._run_native_lib", fake_run_lib), patch(
            "jaclang.cli.commands.execution.run", fake_run
        ), patch("os.execv", fake_execv) {
            rc = exec_cmds.run_jab_image(img, None, ["arg1"], False, "img");
            assert rc == 0 , "host-driven run must complete";
            assert exec_calls == [] , (
                "interop artifacts never execv -- only the "
                "in-process host resolves na->sv callbacks"
            );
            assert lib_calls == [] , ("interop artifacts never plain-dlopen");
            assert run_calls == [str(img / "main.jac")] , (
                "dispatch must fall to the Python host run"
            );
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "app_metadata reads interop from the seal-time record, not artifact presence" {
    tmp = tempfile.mkdtemp(prefix="jac_meta_interop_");
    try {
        pkg = Path(tmp) / "pkg";
        triple_dir = pkg / ".jac" / "native" / "x86_64-unknown-linux-gnu";
        triple_dir.mkdir(parents=True);
        (pkg / "jac.toml").write_text(
            '[project]\nname = "metaapp"\nversion = "0.1.0"\n'
                + 'entry-point = "main.jac"\n',
            encoding="utf-8"
        );
        (pkg / "main.jac").write_text("with entry { }\n", encoding="utf-8");
        import from jaclang.utils.precompile_bytecode { app_metadata }

        # A lib-only payload without a seal-time record is NOT interop: only
        # nacompile_sealed_pair's decision (the record file) may claim it.
        (triple_dir / native_lib_name("main")).write_bytes(b"");
        meta = app_metadata(pkg, "metaapp");
        assert meta.get("native") == {"interop": False} , (
            "artifact presence must not imply interop; " f"got {meta.get('native')}"
        );

        record = triple_dir / (native_lib_name("main") + ".interop.json");
        record.write_text(
            json.dumps({"interop": True, "unresolved": ["py_double"]}), encoding="utf-8"
        );
        meta = app_metadata(pkg, "metaapp");
        assert meta.get("native") == {"interop": True, "unresolved": ["py_double"]} , f"seal-time record must mark the app interop; got {meta.get(
            'native'
        )}";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
