"""The host-driven entry-library lane for sealed native jabs.

A seal compiles once and links the native pair from that single plan: the
standalone executable (the exe-first lane) and, beside it, the entry
library -- the one shared artifact that also exports the host protocol
(`jac_entry`, `__jac_argc`/`__jac_argv`, a `__jac_bind_*` dispatch slot per
native->Python callback) -- so it loads under RTLD_NOW carrying no
unresolved Python symbols. An app whose native code calls into Python
cannot be self-contained, so its pair collapses to the entry library plus
a `<lib>.interop.json` record of the callback contract; the runner loads
it in-process in host order: dlopen, argv, callbacks, `__jac_shared_init`,
`jac_entry`. A corrupt or stale record is loud, never assumed away.
"""

import os;
import sys;
import json;
import ctypes;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.cli.commands { execution as exec_cmds }
import from jaclang.cli.commands.native_build { native_build_sealed_pair }
import from jaclang.server.sealed_serve { interop_record_path, native_lib_name }
import from jaclang.dist.precompile_bytecode { _native_payload_meta, app_metadata }
import from jaclang.dist.jab { jab_app_meta }


glob _TOML_TAIL_TOML: str = (
         '[project]\nname = "{name}"\nversion = "0.1.0"\n'
         'entry-point = "main"\nkind = "cli-native"\n'
     ),
     _PINS: str = '\n[placement.pins]\nmain = "native"\nhelper = "server"\n';


def _llvm_ready -> bool {
    if not sys.platform.startswith("linux") {
        return False;
    }
    try {
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        return "x86_64" in str(llvm.get_default_triple());
    } except Exception {
        return False;
    }
}


def _write_project(proj: Path, name: str, interop: bool) -> Path {
    if interop {
        (proj / "helper.jac").write_text(
            "import sys;\n"
            "import from pathlib { Path }\n\n"
            "def:pub py_double(x: int) -> int {\n"
            "    if sys.argv and sys.argv[-1].endswith(\"entry-lib-argv-probe\") {\n"
            "        Path(sys.argv[-1]).write_text(sys.argv[0], encoding=\"utf-8\");\n"
            "    }\n"
            "    return x * 2;\n"
            "}\n",
            encoding="utf-8"
        );
        (proj / "main.jac").write_text(
            "import from .helper { py_double as twice }\n\n"
            "with entry {\n    print(twice(21));\n}\n",
            encoding="utf-8"
        );
        pins = _PINS;
    } else {
        (proj / "main.jac").write_text(
            "with entry { print(\"sealed\"); }\n", encoding="utf-8"
        );
        pins = "";
    }
    (proj / "jac.toml").write_text(
        _TOML_TAIL_TOML.replace("{name}", name) + pins, encoding="utf-8"
    );
    return proj / "main.jac";
}


def _seal_pair(proj: Path, interop: bool) -> tuple[(Path, Path)] {
    main_file = _write_project(proj, "entrylane", interop);
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    triple = str(llvm.get_default_triple());
    out = proj / ".jac" / "native" / triple;
    out.mkdir(parents=True);
    exe = out / "main";
    lib = out / native_lib_name("main");
    rc = native_build_sealed_pair(
        filename=str(main_file), exe_output=str(exe), lib_output=str(lib)
    );
    assert rc == 0 , "sealed-pair build failed";
    return (exe, lib);
}


test "native_lib_name carries the host shared-library suffix" {
    if sys.platform.startswith("win") {
        assert native_lib_name("main") == "main.dll";
    } elif sys.platform == "darwin" {
        assert native_lib_name("main") == "main.dylib";
    } else {
        assert native_lib_name("main") == "main.so";
    }
}


test "_jab_interop_record reads absent, ok and corrupt records distinctly" {
    with tempfile.TemporaryDirectory() as d {
        lib = Path(d) / "main.so";
        lib.write_text("stub", encoding="utf-8");
        (record, status) = exec_cmds._jab_interop_record(str(lib));
        assert status == "absent" and record is None , "no record file";
        record_path = interop_record_path(str(lib));
        record_path.write_text(
            json.dumps(
                {
                    "interop": True,
                    "version": 1,
                    "sha256": "0" * 64,
                    "triple": "test-triple",
                    "callbacks": [
                        {
                            "symbol": "caller.f",
                            "name": "f",
                            "source": "m.jac",
                            "ret_type": "int",
                            "param_types": []
                        }
                    ]
                }
            ),
            encoding="utf-8"
        );
        (record, status) = exec_cmds._jab_interop_record(str(lib));
        assert status == "ok" and record is not None;
        assert record["callbacks"][0]["name"] == "f";
        record_path.write_text("{not json", encoding="utf-8");
        (record, status) = exec_cmds._jab_interop_record(str(lib));
        assert status == "corrupt" and record is None , (
            "a corrupt record must be loud (warned), never assumed"
        );
    }
}


test "a non-interop seal links exe plus entry lib, and the lib runs in-process" {
    if not _llvm_ready() {
        testskip("linux x86_64 native linking required");
    }
    with tempfile.TemporaryDirectory() as d {
        proj = Path(d) / "proj";
        proj.mkdir();
        (exe, lib) = _seal_pair(proj, interop=False);
        assert exe.is_file() , "self-contained app keeps its standalone exe";
        assert lib.is_file() , "the pair includes the entry library";
        assert not interop_record_path(str(lib)).exists() , (
            "no callback contract: absence of the record is what makes the "
            "runner go exe-first"
        );
        """RTLD_NOW only resolves when the library carries no unresolved
        Python symbols -- the entry-library protocol guarantee.""";
        handle = ctypes.CDLL(
            str(lib), mode=getattr(os, "RTLD_NOW", 0) | getattr(os, "RTLD_LOCAL", 0)
        );
        for export in ["jac_entry", "__jac_shared_init", "__jac_argc", "__jac_argv"] {
            assert hasattr(handle, export) , f"entry lib must export {export}";
        }
        """The fallback lane: no exe on PATH of the image, no record -- the
        lib still runs (argv, init, entry) in-process.""";
        rc = exec_cmds._jab_run_entry_lib(
            proj,
            "main.jac",
            [],
            "entrylane",
            native_meta=_native_payload_meta(proj / ".jac" / "native")
        );
        assert rc == 0 , f"in-process fallback lane failed: {rc}";
    }
}


test "an interop seal collapses to entry lib plus a faithful record" {
    if not _llvm_ready() {
        testskip("linux x86_64 native linking required");
    }
    import hashlib;
    with tempfile.TemporaryDirectory() as d {
        proj = Path(d) / "proj";
        proj.mkdir();
        (exe, lib) = _seal_pair(proj, interop=True);
        assert not exe.exists() , (
            "an interop app cannot be self-contained: no standalone exe"
        );
        record_path = interop_record_path(str(lib));
        assert record_path.is_file();
        data = json.loads(record_path.read_text(encoding="utf-8"));
        assert data["interop"] is True;
        assert data["triple"];
        h = hashlib.sha256();
        h.update(lib.read_bytes());
        assert data["sha256"] == h.hexdigest() , "record pins the lib build";
        native_meta = _native_payload_meta(lib.parent.parent);
        assert native_meta[data["triple"]]["record_sha256"]
            == (hashlib.sha256(record_path.read_bytes()).hexdigest());
        assert len(data["callbacks"]) == 1 , data["callbacks"];
        cb = data["callbacks"][0];
        assert cb["symbol"].endswith(".twice");
        assert cb["name"] == "py_double";
        assert cb["ret_type"] == "int" and cb["param_types"] == ["int"];
        assert cb["source"] == "helper.jac" , (
            "the record names the provider module relative to the project"
        );
        """The library exposes a dispatch slot for the callback and keeps
        the protocol surface the host drives.""";
        handle = ctypes.CDLL(
            str(lib), mode=getattr(os, "RTLD_NOW", 0) | getattr(os, "RTLD_LOCAL", 0)
        );
        assert hasattr(handle, "__jac_bind_" + cb["symbol"]);
        for export in ["jac_entry", "__jac_argc", "__jac_argv"] {
            assert hasattr(handle, export);
        }
    }
}


test "argv is live before any user code runs in the entry library" {
    if not _llvm_ready() {
        testskip("linux x86_64 native linking required");
    }
    with tempfile.TemporaryDirectory() as d {
        # The fixture captures len(sys.argv) in a glob initializer. It runs
        # inside __jac_shared_init, before the host could repair argv later.
        # If argv were set after init, the captured count would be empty.
        proj = Path(d);
        fixture = proj / "argv_fixture.jac";
        fixture.write_text(
            "import sys;\n\n"
            "glob captured: int = len(sys.argv);\n\n"
            "def:pub get_captured_argc() -> int {\n    return captured;\n}\n\n"
            "with entry { }\n",
            encoding="utf-8"
        );
        out = proj / "out";
        out.mkdir();
        lib = out / native_lib_name("argv_fixture");
        rc = native_build_sealed_pair(
            filename=str(fixture),
            exe_output=str(out / "argv_fixture"),
            lib_output=str(lib)
        );
        assert rc == 0;
        assert lib.is_file();
        import from jaclang.runtime.interop_bridge { NativeLibrary }
        nl = NativeLibrary(path=str(lib), eager=True);
        host_argv = ["/sealed/main.jac", "alpha", "beta"];
        exec_cmds._set_native_argv_in_dll(nl, host_argv[0], host_argv[1:]);
        handle = nl.handle();
        shared_init = handle.__jac_shared_init;
        shared_init.restype = None;
        shared_init.argtypes = [];
        shared_init();
        captured = handle.get_captured_argc;
        captured.restype = ctypes.c_int64;
        assert int(captured()) == len(host_argv) , (
            f"glob init saw argc={int(captured())}, expected {len(host_argv)} "
            "(init ran before the host wrote argv)"
        );
    }
}


test "the interop lane loads, verifies and runs a sealed image in-process" {
    if not _llvm_ready() {
        testskip("linux x86_64 native linking required");
    }
    with tempfile.TemporaryDirectory() as d {
        proj = Path(d);
        (_, lib) = _seal_pair(proj, interop=True);
        marker = proj / "entry-lib-argv-probe";
        saved_argv = sys.argv;
        native_meta = _native_payload_meta(proj / ".jac" / "native");
        rc = exec_cmds._jab_run_entry_lib(
            proj, "main.jac", [str(marker)], "entrylane", native_meta=native_meta
        );
        assert rc == 0 , "the in-process interop lane must run the entry";
        assert sys.argv is saved_argv , "the entry lane must restore host argv";
        assert marker.read_text(encoding="utf-8") == str(lib.with_suffix("")) , (
            "Python callbacks must see the app argv before provider import/call"
        );
        """A record describing a different build must be refused (stale
        product), and a corrupt one must never be assumed away.""";
        record_path = interop_record_path(str(lib));
        data = json.loads(record_path.read_text(encoding="utf-8"));
        valid_symbol = data["callbacks"][0]["symbol"];
        import hashlib;
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        triple = str(llvm.get_default_triple());
        trusted_meta = _native_payload_meta(proj / ".jac" / "native");
        data["callbacks"][0]["symbol"] = "missing_callback";
        h = hashlib.sha256();
        h.update(lib.read_bytes());
        data["sha256"] = h.hexdigest();
        record_path.write_text(json.dumps(data), encoding="utf-8");
        assert exec_cmds._jab_run_entry_lib(
            proj, "main.jac", [], "entrylane", native_meta=trusted_meta
        )
            is None , "sealed metadata must detect a changed callback record";
        trusted_meta[triple]["record_sha256"] = (
            hashlib.sha256(record_path.read_bytes()).hexdigest()
        );
        assert exec_cmds._jab_run_entry_lib(
            proj, "main.jac", [], "entrylane", native_meta=trusted_meta
        )
            is None , "the lane must verify every recorded bind slot";
        data["callbacks"][0]["symbol"] = "py_double";
        data["sha256"] = "0" * 64;
        record_path.write_text(json.dumps(data), encoding="utf-8");
        trusted_meta[triple]["record_sha256"] = (
            hashlib.sha256(record_path.read_bytes()).hexdigest()
        );
        assert exec_cmds._jab_run_entry_lib(
            proj, "main.jac", [], "entrylane", native_meta=trusted_meta
        )
            is None , "stale sha256: the lane must refuse, not run";
        data["callbacks"][0]["symbol"] = valid_symbol;
        data["callbacks"][0]["source"] = "../outside.jac";
        h = hashlib.sha256();
        h.update(lib.read_bytes());
        data["sha256"] = h.hexdigest();
        record_path.write_text(json.dumps(data), encoding="utf-8");
        trusted_meta[triple]["record_sha256"] = (
            hashlib.sha256(record_path.read_bytes()).hexdigest()
        );
        assert exec_cmds._jab_run_entry_lib(
            proj, "main.jac", [], "entrylane", native_meta=trusted_meta
        )
            is None , "callback source paths must stay inside the sealed image";
        record_path.write_text("{truncated", encoding="utf-8");
        assert exec_cmds._jab_run_entry_lib(
            proj, "main.jac", [], "entrylane", native_meta=trusted_meta
        )
            is None , "corrupt record: the lane must refuse, not assume";
        record_path.unlink();
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        triple = str(llvm.get_default_triple());
        assert exec_cmds._jab_run_entry_lib(
            proj, "main.jac", [], "entrylane", native_meta=trusted_meta
        )
            is None , "missing record for interop metadata must refuse the lib";
    }
}


test "a standalone binary stays exe-first: execv, not the lib lane" {
    class ExecReplaced(Exception) {}
    with tempfile.TemporaryDirectory() as d {
        img = Path(d);
        (img / "_precompiled").mkdir();
        (img / "main.jac").write_text("with entry { }\n", encoding="utf-8");
        (img / "_precompiled" / "MANIFEST.json").write_text(
            json.dumps(
                {
                    "kind": "native-binary",
                    "entry": {"path": "main.jac"},
                    "capabilities": []
                }
            ),
            encoding="utf-8"
        );
        execed: list[tuple[str, list[str]]] = [];
        def fake_execv(path: str, argv: list[str]) {
            execed.append((path, argv));
            raise ExecReplaced("exec replaced process");
        }
        with patch.object(
            exec_cmds, "_jab_native_bin", return_value="/img/native/main"
        ), patch.object(exec_cmds.os, "execv", side_effect=fake_execv), patch.object(
            exec_cmds, "_jab_run_entry_lib"
        ) as lib_lane {
            replaced = False;
            try {
                exec_cmds.run_jab_image(img, None, [], False, "entrylane");
            } except ExecReplaced {
                replaced = True;
            }
            assert replaced , "execv must replace the process";
        }
        assert execed , "the standalone binary must be exec'd";
        assert execed[0][0] == "/img/native/main";
        assert not lib_lane.called , "exe-first: the lib lane is not consulted";
        with patch.object(
            exec_cmds, "_jab_native_bin", return_value="/img/native/main"
        ), patch.object(exec_cmds.os, "execv", side_effect=OSError("cannot start")), patch.object(
            exec_cmds, "_jab_run_entry_lib", return_value=7
        ) as fallback_lane {
            assert exec_cmds.run_jab_image(img, None, [], False, "entrylane") == 7;
            assert fallback_lane.called , "failed execv must try the entry lib";
        }
    }
}

test "sealed package and entry-library native metadata coexist" {
    with tempfile.TemporaryDirectory() as d {
        proj = Path(d) / "proj";
        proj.mkdir();
        _write_project(proj, "manifestmix", False);
        payload_dir = proj / ".jac" / "native" / "test-triple";
        payload_dir.mkdir(parents=True);
        (payload_dir / "main.so").write_bytes(b"entry library");
        app_meta = app_metadata(proj, "manifestmix");
        payload_meta = app_meta.get("native_payloads") or {};
        assert "test-triple" in payload_meta;
        assert "native" not in app_meta , (
            "per-target payload metadata must not occupy the package native key"
        );
        package_native = {
            "units": ["manifestmix.main"],
            "artifact": {"path": "native/libmanifestmix.so", "sha256": "trusted"}
        };
        app_meta["native"] = package_native;
        image = Path(d) / "image";
        manifest_dir = image / "_precompiled";
        manifest_dir.mkdir(parents=True);
        (manifest_dir / "MANIFEST.json").write_text(
            json.dumps(app_meta), encoding="utf-8"
        );
        loaded = jab_app_meta(image);
        assert loaded.get("native") == package_native;
        loaded_payloads = loaded.get("native_payloads") or {};
        assert loaded_payloads == payload_meta , (
            "sealing must preserve every per-target library and sidecar digest"
        );
    }
}

test "entry-library metadata digest rejects a stale plain library" {
    if not _llvm_ready() {
        testskip("native binding required to select the host triple");
    }
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    triple = str(llvm.get_default_triple());
    with tempfile.TemporaryDirectory() as d {
        image = Path(d);
        native_dir = image / ".jac" / "native" / triple;
        native_dir.mkdir(parents=True);
        lib = native_dir / native_lib_name("main");
        lib.write_bytes(b"tampered plain entry library");
        trusted_meta = {triple: {"sha256": "0" * 64, "interop": False}};
        rc = exec_cmds._jab_run_entry_lib(
            image, "main.jac", [], "entrylane", native_meta=trusted_meta
        );
        assert rc is None , "a stale plain library must not reach dlopen";
    }
}
