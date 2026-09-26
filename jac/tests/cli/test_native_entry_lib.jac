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
import from jaclang.cli.commands.native_build { native_build, _build_native_entry_lib }
import from jaclang.project.config { JacConfig }
import from jaclang.server.sealed_serve {
    native_lib_name,
    native_lib_suffix,
    NATIVE_DIR_REL
}


def _llvm_available -> bool {
    try {
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        llvm.get_default_triple();
        return True;
    } except Exception {
        return False;
    }
}


def _bake(config: any, pkg_copy: Path) -> bool {
    import from jaclang.dist.seal { bake_native_payloads }
    return bake_native_payloads(config, pkg_copy);
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
            + f'entry-point = "main"\nkind = "cli-native"\n{pins}',
        encoding="utf-8"
    );
    return JacConfig.load(proj_root / "jac.toml");
}


test "NativeArgv builds argc and keeps encoded argv pointers alive" {
    argv = ["/tmp/app.jac", "hello", "world"];
    native_argv = exec_cmds.NativeArgv(argv);
    assert native_argv.argc == 3 , f"expected argc 3, got {native_argv.argc}";
    assert len(native_argv.refs) == 3 , "one c_char_p per argument";
    assert native_argv.refs[0].value == b"/tmp/app.jac" , "argv strings must be UTF-8 encoded";
    assert native_argv.vector[1] == b"hello" and native_argv.vector[2] == b"world" , (
        "the char** vector must expose the encoded arguments"
    );
}


test "native_lib_name uses the platform shared-library suffix" {
    if sys.platform.startswith("win") {
        assert native_lib_name("main") == "main.dll";
    } elif sys.platform == "darwin" {
        assert native_lib_name("main") == "main.dylib";
    } else {
        assert native_lib_name("main") == "main.so";
    }
}


test "resolve_sv_callbacks finds a nested provider under the image root" {
    import from jaclang.runtime.interop_bridge { resolve_sv_callbacks }
    tmp = tempfile.mkdtemp(prefix="jac_sv_resolve_");
    try {
        img = Path(tmp);
        lib_dir = img / "lib";
        lib_dir.mkdir();
        (lib_dir / "nested_helper.jac").write_text(
            "def:pub nested_double(x: int) -> int {\n    return x * 2;\n}\n",
            encoding="utf-8"
        );
        for src in ["lib/nested_helper.jac", "lib.nested_helper"] {
            callbacks = [
                {
                    "name": "nested_double",
                    "ret_type": "int",
                    "param_types": ["int"],
                    "source_module": src
                }
            ];
            fns = resolve_sv_callbacks(callbacks, str(img));
            assert "nested_double" in fns , (
                f"source_module {src!r} must resolve to lib/nested_helper.jac"
            );
            assert fns["nested_double"](21) == 42;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "_jab_native_lib resolves the sealed native artifact path" {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    try {
        triple = llvm.get_default_triple();
    } except Exception {
        testskip("LLVM toolchain unavailable");
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
    rc = exec_cmds._run_native_lib(
        "/no/such/lib.so", ["app.jac"], img_root=Path("/no/such/img")
    );
    assert rc is None , "load failure must fall back to the standalone binary";
}


test "_run_native_lib returns None when required exports are missing" {
    class _StubLib {
        def __jac_shared_init(self: _StubLib) {}
    }
    stub = _StubLib();
    with patch("ctypes.CDLL", return_value=stub), patch.object(
        exec_cmds, "_set_native_argv_in_dll", return_value=True
    ) {
        rc = exec_cmds._run_native_lib("fake.so", ["app.jac"], img_root=Path("."));
    }
    assert rc is None , "missing jac_entry must fall back, not abort the jab run";
}


test "entry_lib runs __jac_shared_init only after argv is populated (Linux)" {
    if not sys.platform.startswith("linux") {
        testskip("linux-only native linking");
    }
    import ctypes;
    fixture = os.path.join(
        TESTS_DIR,
        "compiler",
        "backends",
        "native",
        "fixtures",
        "entry_lib_argv_init.jac"
    );
    with tempfile.TemporaryDirectory() as d {
        lib_out = os.path.join(d, "entry.so");
        rc = _build_native_entry_lib(filename=fixture, output=lib_out);
        assert rc == 0 , "entry_lib native_build failed";
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
        testskip("linux-only native linking");
    }
    fixture = os.path.join(
        TESTS_DIR,
        "compiler",
        "backends",
        "native",
        "fixtures",
        "entry_lib_argv_init.jac"
    );
    with tempfile.TemporaryDirectory() as d {
        lib_out = os.path.join(d, "entry.so");
        assert _build_native_entry_lib(filename=fixture, output=lib_out) == 0;
        host_argv = ["/sealed/main.jac"];
        rc = exec_cmds._run_native_lib(lib_out, host_argv, img_root=Path(d));
        assert rc == 0 , "_run_native_lib should run jac_entry successfully";
    }
}


test "_bake_native_payloads accepts native_build_sealed_pair success (return 0)" {
    if not _llvm_available() {
        testskip("LLVM toolchain unavailable");
    }
    tmp = tempfile.mkdtemp(prefix="jac_native_seal_");
    try {
        project_dir = Path(tmp) / "proj";
        project_dir.mkdir();
        config = _seal_fixture_project(project_dir, "sealtest");
        pkg_copy = Path(tmp) / "stage";
        pkg_copy.mkdir();
        with patch(
            "jaclang.cli.commands.native_build.native_build_sealed_pair", return_value=0
        ) as mock_pair {
            ok = _bake(config, pkg_copy);
        }
        assert ok , (
            "return 0 from native_build_sealed_pair must not abort native bake "
            "(Jac treats 0 as falsy — check != 0, not `if not`)"
        );
        assert mock_pair.called , "expected native_build_sealed_pair to be invoked";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "_bake_native_payloads fails when native_build_sealed_pair returns non-zero" {
    if not _llvm_available() {
        testskip("LLVM toolchain unavailable");
    }
    tmp = tempfile.mkdtemp(prefix="jac_native_seal_");
    try {
        project_dir = Path(tmp) / "proj";
        project_dir.mkdir();
        config = _seal_fixture_project(project_dir, "sealtest");
        pkg_copy = Path(tmp) / "stage";
        pkg_copy.mkdir();
        with patch(
            "jaclang.cli.commands.native_build.native_build_sealed_pair", return_value=1
        ) {
            ok = _bake(config, pkg_copy);
        }
        assert not ok , "non-zero native_build_sealed_pair must abort native bake";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "sealed pair on a native_imports app drops the exe and keeps the lib" {
    if not sys.platform.startswith("linux") {
        testskip("linux-only native linking");
    }
    if not _llvm_available() {
        testskip("LLVM toolchain unavailable");
    }
    tmp = tempfile.mkdtemp(prefix="jac_interop_seal_");
    try {
        proj = Path(tmp) / "proj";
        proj.mkdir();
        _seal_fixture_project(proj, "interopseal", interop=True);
        exe_out = str(proj / "main");
        import from jaclang.cli.commands.native_build { native_build_sealed_pair }
        rc = native_build_sealed_pair(
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


test "_run_native_lib executes na->sv callbacks resolved from the image root (Linux)" {
    if not sys.platform.startswith("linux") {
        testskip("linux-only native linking");
    }
    if not _llvm_available() {
        testskip("LLVM toolchain unavailable");
    }
    tmp = tempfile.mkdtemp(prefix="jac_callback_root_");
    try {
        proj = Path(tmp) / "proj";
        proj.mkdir();
        _seal_fixture_project(proj, "callbackroot", interop=True);
        marker = Path(tmp) / "marker.txt";
        (proj / "helper.jac").write_text(
            "import from pathlib { Path }\n\n"
            "def:pub py_double(x: int) -> int {\n"
            f"    Path({str(marker)!r}).write_text(str(x * 2));\n"
            "    return x * 2;\n"
            "}\n",
            encoding="utf-8"
        );
        import from jaclang.cli.commands.native_build { native_build_sealed_pair }
        lib_out = str(proj / "libmain.entry.so");
        assert native_build_sealed_pair(
            filename=str(proj / "main.jac"),
            exe_output=str(proj / "main"),
            lib_output=lib_out
        )
            == 0 , "interop seal must produce the host-driven entry library";

        # Stage the sealed layout the jab host runs: the library under
        # .jac/native/<triple>, its interop sidecar beside it, and the
        # callback source module at the image root. The library path alone
        # must not be used to locate callback sources.
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        img = Path(tmp) / "img";
        lib_dir = img / NATIVE_DIR_REL / llvm.get_default_triple();
        lib_dir.mkdir(parents=True);
        sealed_lib = lib_dir / "libmain.entry.so";
        shutil.copy2(lib_out, sealed_lib);
        shutil.copy2(
            Path(lib_out + ".interop.json"), Path(str(sealed_lib) + ".interop.json")
        );
        (img / "helper.jac").write_text(
            (proj / "helper.jac").read_text(encoding="utf-8"), encoding="utf-8"
        );

        callbacks = exec_cmds._jab_interop_callbacks(str(sealed_lib));
        assert callbacks , "the seal must record the callback contract";
        assert callbacks[0].get("name") == "py_double" , (
            f"unexpected callback contract: {callbacks}"
        );
        rc = exec_cmds._run_native_lib(
            str(sealed_lib), [str(img / "main.jac")], callbacks=callbacks, img_root=img
        );
        assert rc == 0 , "the native entry must run to completion";
        assert marker.is_file() , (
            "the native entry must have called back into the Python helper "
            "resolved from the image root (a wrong root leaves the dispatch "
            "slot empty and silently returns 0)"
        );
        assert marker.read_text(encoding="utf-8") == "42" , (
            "the callback must receive 21 and return 42 into native code"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "standalone exe native_build still rejects native_imports" {
    if not _llvm_available() {
        testskip("LLVM toolchain unavailable");
    }
    tmp = tempfile.mkdtemp(prefix="jac_interop_gate_");
    try {
        proj = Path(tmp) / "proj";
        proj.mkdir();
        _seal_fixture_project(proj, "interopseal", interop=True);
        rc = native_build(
            filename=str(proj / "main.jac"), output=str(proj / "blocked")
        );
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
        exec_calls: list[any] = [];
        lib_calls: list[str] = [];
        lib_argvs: list[list[str]] = [];
        root_calls: list[str] = [];

        def fake_execv(path: str, argv: list[str]) {
            exec_calls.append((path, list(argv)));
            raise SystemExit(7);
        }

        def fake_run_lib(
            lib_path: str, argv: list[str], callbacks: any = None, img_root: any = None
        ) -> (int | None) {
            lib_calls.append(lib_path);
            lib_argvs.append(list(argv));
            root_calls.append(str(img_root));
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
            assert exec_calls[0][1] == [str(img / "bin"), "arg1"] , (
                "execv argv must be [exe, *user_args] -- the sealed entry "
                f"path is not a user argument; got {exec_calls[0][1]}"
            );
            assert lib_calls == [] , (
                "a self-contained exe replaces the process before " "any dlopen rung"
            );
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "run_jab_image loads interop jabs in-process and never execs them" {
    tmp = tempfile.mkdtemp(prefix="jac_dispatch_host_");
    try {
        img = Path(tmp) / "img";
        img.mkdir();
        _fake_jab_image(img, interop=True);
        exec_calls: list[str] = [];
        lib_calls: list[str] = [];
        lib_argvs: list[list[str]] = [];
        cb_calls: list[list[dict[str, any]]] = [];
        root_calls: list[str] = [];
        run_calls: list[any] = [];

        def fake_execv(path: str, argv: list[str]) {
            exec_calls.append(path);
            raise SystemExit(7);
        }

        def fake_run_lib(
            lib_path: str, argv: list[str], callbacks: any = None, img_root: any = None
        ) -> (int | None) {
            lib_calls.append(lib_path);
            lib_argvs.append(list(argv));
            cb_calls.append(list(callbacks or []));
            root_calls.append(str(img_root));
            return 0;
        }

        def fake_run(target: str, args: list[str]) -> int {
            run_calls.append((target, list(args)));
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
            assert lib_calls == [str(img / "lib")] , (
                "interop artifacts must be loaded in-process via the "
                "NativeLibrary dispatch lane"
            );
            assert lib_argvs == [[str(img / "main.jac"), "arg1"]] , (
                "the in-process lane must see host argv [entry, *args]; "
                f"got {lib_argvs}"
            );
            assert cb_calls == [[]] , (
                "the interop lane must consult the interop record (empty "
                f"contract for this stub image); got {cb_calls}"
            );
            assert root_calls == [str(img)] , (
                "the entry-lib lane must pass the sealed image root down "
                f"for callback source resolution; got {root_calls}"
            );
            assert run_calls == [] , (
                "a successful in-process load must not fall back to the "
                "JIT interpreter"
            );
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "started native entry never falls back to the JIT in either lane" {
    for interop in [True, False] {
        tmp = tempfile.mkdtemp(prefix="jac_started_entry_");
        try {
            img = Path(tmp) / "img";
            img.mkdir();
            _fake_jab_image(img, interop=interop);
            jit_calls: list[str] = [];
            exec_calls: list[str] = [];

            def fake_run(target: str, args: list[str]) -> int {
                jit_calls.append(target);
                return 0;
            }

            def fake_execv(path: str, argv: list[str]) {
                exec_calls.append(path);
                raise SystemExit(0);
            }

            def raising_lib(
                lib_path: str,
                argv: list[str],
                callbacks: any = None,
                img_root: any = None
            ) -> (int | None) {
                raise exec_cmds.NativeEntryStartedError("entry already ran");
            }

            with patch(
                "jaclang.cli.commands.execution._jab_native_lib",
                return_value=str(img / "lib")
            ), patch(
                "jaclang.cli.commands.execution._jab_native_bin", return_value=None
            ), patch("jaclang.cli.commands.execution._run_native_lib", raising_lib), patch(
                "jaclang.cli.commands.execution.run", fake_run
            ), patch("os.execv", fake_execv) {
                rc = exec_cmds.run_jab_image(img, None, [], False, "img");
                assert rc == 1 , (
                    "a failure after jac_entry started must surface as a "
                    "clean CLI error, not a fallback that re-runs the entry"
                );
                assert jit_calls == [] , (
                    "the JIT interpreter must not run once the entry started"
                );
                assert exec_calls == [] , (
                    "the standalone exe must not exec once the entry started"
                );
            }
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
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
                + 'entry-point = "main"\n',
            encoding="utf-8"
        );
        (pkg / "main.jac").write_text("with entry { }\n", encoding="utf-8");
        import from jaclang.dist.precompile_bytecode { app_metadata }

        # A lib-only payload without a seal-time record is NOT interop: only
        # native_build_sealed_pair's decision (the record file) may claim it.
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


test "unreadable interop record marks the app non-interop" {
    tmp = tempfile.mkdtemp(prefix="jac_meta_corrupt_");
    try {
        pkg = Path(tmp) / "pkg";
        triple_dir = pkg / ".jac" / "native" / "x86_64-unknown-linux-gnu";
        triple_dir.mkdir(parents=True);
        (pkg / "jac.toml").write_text(
            '[project]\nname = "corruptmeta"\nversion = "0.1.0"\n'
                + 'entry-point = "main"\n',
            encoding="utf-8"
        );
        (pkg / "main.jac").write_text("with entry { }\n", encoding="utf-8");
        import from jaclang.dist.precompile_bytecode { app_metadata }

        (triple_dir / native_lib_name("main")).write_bytes(b"");
        (triple_dir / (native_lib_name("main") + ".interop.json")).write_text(
            "{ not json at all", encoding="utf-8"
        );
        meta = app_metadata(pkg, "metaapp");
        assert meta.get("native") == {"interop": False} , (
            "an unreadable record must fail conservative (JIT lane), "
            f"not steer into the in-process lane; got {meta.get('native')}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "_run_native_lib refuses a stale interop record before init runs" {
    inits: list[bool] = [];
    class _StubLib {
        def __jac_shared_init(self: _StubLib) {
            inits.append(True);
        }
    }
    stub = _StubLib();
    with patch("ctypes.CDLL", return_value=stub), patch.object(
        exec_cmds, "_set_native_argv_in_dll", return_value=True
    ) {
        rc = exec_cmds._run_native_lib(
            "fake.so",
            ["app.jac"],
            callbacks=[{"name": "pyz", "ret_type": "int", "param_types": ["int"]}],
            img_root=Path(".")
        );
    }
    assert rc is None , (
        "a record naming a bind slot the library lacks must be refused, "
        "not run with a null dispatch slot"
    );
    assert not inits , (
        "__jac_shared_init must not run when the interop record is stale "
        "(a JIT fallback after init would re-run module side effects)"
    );
}


test "sized scalars map to width-correct ctypes trampolines" {
    import ctypes;
    import from jaclang.runtime.interop_bridge { JAC_TO_CTYPES, JAC_TO_CTYPES_STR }
    assert JAC_TO_CTYPES["f32"] is ctypes.c_float , (
        "f32 must trampoline as c_float, not the c_int64 fallback"
    );
    assert JAC_TO_CTYPES["f64"] is ctypes.c_double;
    assert JAC_TO_CTYPES["i8"] is ctypes.c_int8;
    assert JAC_TO_CTYPES["u8"] is ctypes.c_uint8;
    assert JAC_TO_CTYPES["i16"] is ctypes.c_int16;
    assert JAC_TO_CTYPES["u32"] is ctypes.c_uint32;
    assert JAC_TO_CTYPES["i64"] is ctypes.c_int64;
    assert JAC_TO_CTYPES["u64"] is ctypes.c_uint64;
    assert JAC_TO_CTYPES_STR["f32"] == "ctypes.c_float";
    assert JAC_TO_CTYPES["int"] is ctypes.c_int64 , "base wire map preserved";
}


test "None-returning callback builds a void trampoline" {
    import ctypes;
    import from jaclang.runtime.interop_bridge { register_py_callbacks }
    class _Binding {
        has name: str = "noop",
            ret_type: str = "None",
            param_types: list[str] = [];
    }
    def _no_register(sym: str, addr: int) {}
    table: dict[(str, Callable[(..., object)])] = {};
    cbs: list[object] = [];
    register_py_callbacks([_Binding()], table, cbs, _no_register);
    assert len(cbs) == 1 , (
        "a None-returning na->sv binding must build its trampoline "
        "instead of erroring"
    );
}


test "seal succeeds when a native module imports a server fn it never calls" {
    if not sys.platform.startswith("linux") {
        testskip("linux-only native linking");
    }
    if not _llvm_available() {
        testskip("LLVM toolchain unavailable");
    }
    tmp = tempfile.mkdtemp(prefix="jac_uncalled_import_");
    try {
        proj = Path(tmp) / "proj";
        proj.mkdir();
        (proj / "helper.jac").write_text(
            "def:pub unused_fn(x: int) -> int {\n    return x;\n}\n", encoding="utf-8"
        );
        (proj / "main.jac").write_text(
            "import from .helper { unused_fn }\n\nwith entry {\n    print(1);\n}\n",
            encoding="utf-8"
        );
        (proj / "jac.toml").write_text(
            '[project]\nname = "uncalled"\nversion = "0.1.0"\n'
                + 'entry-point = "main"\nkind = "cli-native"\n'
                + '[placement.pins]\nmain = "native"\nhelper = "server"\n',
            encoding="utf-8"
        );
        import from jaclang.cli.commands.native_build { native_build_sealed_pair }
        exe_out = str(proj / "main");
        rc = native_build_sealed_pair(
            filename=str(proj / "main.jac"),
            exe_output=exe_out,
            lib_output=str(proj / "libmain.entry.so")
        );
        assert rc == 0 , (
            "an imported-but-uncalled server fn has no IR declaration; the "
            "seal must skip its bind slot instead of crashing on get_function"
        );
        assert os.path.isfile(str(proj / "libmain.entry.so")) , "library sealed";
        assert not os.path.isfile(exe_out) , "interop app drops the standalone exe";
        record = proj / "libmain.entry.so.interop.json";
        assert record.is_file() , "sidecar written after successful link";
        rec = json.loads(record.read_text(encoding="utf-8"));
        assert rec.get("interop") is True;
        assert rec.get("callbacks") == [] , (
            f"the uncalled import must get no callback record; "
            f"got {rec.get('callbacks')}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
