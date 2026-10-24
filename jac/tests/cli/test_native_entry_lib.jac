"""Tests for sealed native entry-library loading helpers and init ordering."""

import os;
import sys;
import json;
import shutil;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.cli.commands { execution as exec_cmds }
import from jaclang.cli.commands { project as proj_cmds }
import from jaclang.cli.commands.native_build { native_build }
import from jaclang.project.config { JacConfig }
import from jaclang.server.sealed_serve { native_lib_name }


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
                    "symbol": "caller.nested_double",
                    "name": "nested_double",
                    "ret_type": "int",
                    "param_types": ["int"],
                    "source": src
                }
            ];
            (fns, failures) = resolve_sv_callbacks(callbacks, str(img));
            assert not failures , f"provider should resolve from image root: {failures}";
            assert "caller.nested_double" in fns , (
                f"source {src!r} must resolve to lib/nested_helper.jac"
            );
            assert fns["caller.nested_double"](21) == 42;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "_run_native_lib returns None when the library cannot be loaded" {
    rc = exec_cmds._run_native_lib(
        Path("/no/such/img"),
        "/no/such/lib.so",
        None,
        "/no/such/img/main.jac",
        [],
        "entrylane"
    );
    assert rc is None , "load failure must fall back before the entry starts";
}


test "_run_native_lib returns None when required exports are missing" {
    with patch("ctypes.CDLL", return_value=object()) {
        rc = exec_cmds._run_native_lib(
            Path("."), "fake.so", None, "app.jac", [], "entrylane"
        );
    }
    assert rc is None , "missing protocol exports must refuse the library";
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
        assert len(rec.get("callbacks") or []) == 1 , (
            f"the record must name the na->sv bindings; got {rec.get('callbacks')}"
        );
        assert rec["callbacks"][0]["name"] == "py_double";
        assert rec["callbacks"][0]["symbol"].endswith(".py_double");
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
        "native_payloads": {"test-triple": {"interop": interop, "sha256": "0" * 64}}
    };
    (pre / "MANIFEST.json").write_text(json.dumps(meta), encoding="utf-8");
    (img_root / "main.jac").write_text("with entry { }\n", encoding="utf-8");
}


test "run_jab_image loads interop jabs in-process and never execs them" {
    tmp = tempfile.mkdtemp(prefix="jac_dispatch_host_");
    try {
        img = Path(tmp) / "img";
        img.mkdir();
        _fake_jab_image(img, interop=True);
        exec_calls: list[str] = [];
        lib_calls: list[any] = [];
        run_calls: list[any] = [];

        def fake_execv(path: str, argv: list[str]) {
            exec_calls.append(path);
            raise SystemExit(7);
        }

        def fake_run_lib(
            img_root: Path,
            entry_rel: str,
            args: list[str],
            label: str,
            native_meta: any = None
        ) -> (int | None) {
            lib_calls.append(
                (str(img_root), entry_rel, list(args), label, native_meta)
            );
            return 0;
        }

        def fake_run(target: str, args: list[str]) -> int {
            run_calls.append((target, list(args)));
            return 0;
        }

        with patch(
            "jaclang.cli.commands.execution._jab_native_bin", return_value=None
        ), patch("jaclang.cli.commands.execution._jab_run_entry_lib", fake_run_lib), patch(
            "jaclang.cli.commands.execution.run", fake_run
        ), patch("os.execv", fake_execv) {
            rc = exec_cmds.run_jab_image(img, None, ["arg1"], False, "img");
            assert rc == 0 , "host-driven run must complete";
            assert exec_calls == [] , "interop image must not exec an absent binary";
            assert len(lib_calls) == 1 , "the host entry-library lane must run once";
            call = lib_calls[0];
            assert call[0] == str(img) and call[1] == "main.jac";
            assert call[2] == ["arg1"] and call[3] == "img";
            assert call[4]["test-triple"]["interop"] is True;
            assert run_calls == [] , "a successful entry-lib run must not JIT-fallback";
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
                img_root: Path,
                entry_rel: str,
                args: list[str],
                label: str,
                native_meta: any = None
            ) -> (int | None) {
                raise exec_cmds.NativeEntryStartedError("entry already ran");
            }

            with patch(
                "jaclang.cli.commands.execution._jab_native_bin", return_value=None
            ), patch("jaclang.cli.commands.execution._jab_run_entry_lib", raising_lib), patch(
                "jaclang.cli.commands.execution.run", fake_run
            ), patch("os.execv", fake_execv) {
                rc = exec_cmds.run_jab_image(img, None, [], False, "img");
                assert rc == 1 , "started native failure must be a clean CLI error";
                assert jit_calls == [] , "JIT must not repeat an entry that started";
                assert exec_calls == [] , "no executable should be started after init";
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
        triple = "x86_64-unknown-linux-gnu";
        triple_dir = pkg / ".jac" / "native" / triple;
        triple_dir.mkdir(parents=True);
        (pkg / "jac.toml").write_text(
            '[project]\nname = "metaapp"\nversion = "0.1.0"\n'
                + 'entry-point = "main"\n',
            encoding="utf-8"
        );
        (pkg / "main.jac").write_text("with entry { }\n", encoding="utf-8");
        import from jaclang.dist.precompile_bytecode { app_metadata }

        # A library without a seal-time record is not an interop artifact.
        lib = triple_dir / native_lib_name("main");
        lib.write_bytes(b"plain entry library");
        meta = app_metadata(pkg, "metaapp");
        payload = (meta.get("native_payloads") or {}).get(triple) or {};
        assert payload.get("interop") is False , (
            "artifact presence must not imply interop; " f"got {payload}"
        );
        assert payload.get("sha256") , "library digest must be recorded";

        record = triple_dir / (native_lib_name("main") + ".interop.json");
        record.write_text(
            json.dumps({"interop": True, "callbacks": []}), encoding="utf-8"
        );
        meta = app_metadata(pkg, "metaapp");
        payload = (meta.get("native_payloads") or {}).get(triple) or {};
        assert payload.get("interop") is True , (
            f"seal-time record must mark interop; got {payload}"
        );
        assert payload.get("record_sha256") , "sidecar digest must be recorded";
        assert payload.get("callbacks") == 0;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "unreadable interop record marks the app non-interop" {
    tmp = tempfile.mkdtemp(prefix="jac_meta_corrupt_");
    try {
        pkg = Path(tmp) / "pkg";
        triple = "x86_64-unknown-linux-gnu";
        triple_dir = pkg / ".jac" / "native" / triple;
        triple_dir.mkdir(parents=True);
        (pkg / "jac.toml").write_text(
            '[project]\nname = "corruptmeta"\nversion = "0.1.0"\n'
                + 'entry-point = "main"\n',
            encoding="utf-8"
        );
        (pkg / "main.jac").write_text("with entry { }\n", encoding="utf-8");
        import from jaclang.dist.precompile_bytecode { app_metadata }

        (triple_dir / native_lib_name("main")).write_bytes(b"entry library");
        (triple_dir / (native_lib_name("main") + ".interop.json")).write_text(
            "{ not json at all", encoding="utf-8"
        );
        meta = app_metadata(pkg, "corruptmeta");
        payload = (meta.get("native_payloads") or {}).get(triple) or {};
        assert payload.get("interop") == "corrupt" , (
            "unreadable sidecar metadata must be marked rejectable, "
            + f"not treated as a plain library; got {payload}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "sized scalars map to width-correct ctypes trampolines" {
    import ctypes;
    import from jaclang.runtime.interop_bridge { JAC_TO_CTYPES }
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
    assert JAC_TO_CTYPES["int"] is ctypes.c_int64 , "base wire map preserved";
}


test "None-returning callback builds a void trampoline" {
    import ctypes;
    import from jaclang.runtime.interop_bridge { register_py_callbacks }
    class _Binding {
        has name: str = "noop",
            ret_type: str = "None",
            param_types: list[str] = [],
            native_symbol: str = "";
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
            f"the uncalled import must get no callback record; got {rec.get(
                'callbacks'
            )}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "qualified Python callback keys bind and invoke the callback" {
    import ctypes;
    import from jaclang.runtime.interop_bridge { register_py_callbacks }
    class _Binding {
        has name: str = "py_double",
            ret_type: str = "int",
            param_types: list[str] = ["int"],
            native_symbol: str = "caller.py_double",
            lookup_name: str = "caller.py_double";
    }
    def _double(value: int) -> int {
        return value * 2;
    }
    registered: list[tuple[str, int]] = [];
    def _capture(sym: str, addr: int) {
        registered.append((sym, addr));
    }
    table: dict[(str, Callable[(..., object)])] = {"caller.py_double": _double};
    callbacks: list[object] = [];
    register_py_callbacks([_Binding()], table, callbacks, _capture);
    assert registered[0][0] == "caller.py_double" , registered;
    callback_type = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64);
    callback = callback_type(registered[0][1]);
    assert callback(21) == 42;
}

test "aliased server callbacks resolve by caller-local symbol" {
    if not sys.platform.startswith("linux") or not _llvm_available() {
        testskip("requires the Linux native linker");
    }
    tmp = tempfile.mkdtemp(prefix="jac_native_callback_alias_");
    try {
        proj = Path(tmp);
        (proj / "first.jac").write_text(
            "def:pub foo(x: int) -> int {\n    return x + 1;\n}\n", encoding="utf-8"
        );
        (proj / "second.jac").write_text(
            "def:pub foo(x: int) -> int {\n    return x + 2;\n}\n", encoding="utf-8"
        );
        (proj / "main.jac").write_text(
            "import from .first { foo }\n"
                + "import from .second { foo as bar }\n\n"
                + "with entry {\n    print(foo(1));\n    print(bar(1));\n}\n",
            encoding="utf-8"
        );
        (proj / "jac.toml").write_text(
            '[project]\nname = "callback-alias"\nversion = "0.1.0"\n'
                + 'entry-point = "main"\nkind = "cli-native"\n'
                + '[placement.pins]\nmain = "native"\n'
                + 'first = "server"\nsecond = "server"\n',
            encoding="utf-8"
        );
        import from jaclang.cli.commands.native_build { native_build_sealed_pair }
        lib = str(proj / "libmain.entry.so");
        rc = native_build_sealed_pair(
            filename=str(proj / "main.jac"),
            exe_output=str(proj / "main"),
            lib_output=lib,
            image_root=str(proj)
        );
        assert rc == 0 , "aliased native imports must seal";
        record = json.loads(Path(lib + ".interop.json").read_text(encoding="utf-8"));
        callbacks = record.get("callbacks") or [];
        assert len(callbacks) == 2 , callbacks;
        symbols = {str(cb.get("symbol")) for cb in callbacks};
        assert any(symbol.endswith(".foo") for symbol in symbols) , symbols;
        assert any(symbol.endswith(".bar") for symbol in symbols) , symbols;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "JIT callback registers its native symbol but looks up Python name" {
    import ctypes;
    import from jaclang.runtime.interop_bridge { register_py_callbacks }
    class _Binding {
        has name: str = "py_double",
            ret_type: str = "int",
            param_types: list[str] = ["int"],
            native_symbol: str = "caller.py_double",
            lookup_name: str = "";
    }
    def _double(value: int) -> int {
        return value * 2;
    }
    registered: list[tuple[str, int]] = [];
    def _capture(sym: str, addr: int) {
        registered.append((sym, addr));
    }
    table: dict[(str, Callable[(..., object)])] = {"py_double": _double};
    callbacks: list[object] = [];
    register_py_callbacks([_Binding()], table, callbacks, _capture);
    assert registered[0][0] == "caller.py_double" , registered;
    callback_type = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64);
    callback = callback_type(registered[0][1]);
    assert callback(21) == 42;
}
