"""Guards #8000 (1.1): `jac eject` must never emit a backend that imports
modules deleted by the Postgres clean break (#7947).

Two layers: `build_runtime_closure` fails loudly when an explicitly requested
`extra_seeds` entry does not resolve to a vendorable module (it used to skip
it silently and report success), and `emit_backend` rejects the legacy
sqlalchemy/sqlite `[eject.db]` drivers at eject time now that the runtime
persists natively through Session/PgStore.
"""

import tempfile;
import from pathlib { Path }
import from jaclang.dist.publish.runtime_vendor { build_runtime_closure }
import from jaclang.cli.commands.eject_targets.backend { emit_backend }


test "vendored client bundle imports without compiler services" {
    import subprocess;
    import sys;
    import from jaclang.dist.publish.runtime_vendor {
        _compile_runtime_module,
        _pkg_root
    }
    import from jaclang.compiler.session.session { JacProgram }

    pkg_root = _pkg_root();
    source = _compile_runtime_module(
        pkg_root, pkg_root / "client" / "client_bundle.jac", JacProgram()
    );
    with tempfile.TemporaryDirectory() as tmp {
        emitted = Path(tmp) / "client_bundle.py";
        emitted.write_text(source, encoding="utf-8");
        probe = '''import builtins
import runpy
import sys
import jaclang.lib.jaclib

original_import = builtins.__import__
def runtime_import(name, *args, **kwargs):
    if name.startswith("jaclang.compiler.backends"):
        raise ImportError("Compiler services are absent from the vendored runtime")
    return original_import(name, *args, **kwargs)

builtins.__import__ = runtime_import
module = runpy.run_path(sys.argv[1])
assert issubclass(module["ClientBundleError"], RuntimeError)
assert issubclass(module["MissingBunError"], module["ClientBundleError"])
''';
        result = subprocess.run(
            [sys.executable, "-c", probe, str(emitted)], capture_output=True, text=True
        );
        assert result.returncode == 0 , result.stderr;
    }
}


test "unresolvable extra seed fails loudly" {
    # This exact module was deleted by #7947; the vendorer used to skip the
    # seed silently and exit 0, leaving a backend that dies on first import.
    with testraises(ValueError) as exc {
        build_runtime_closure(
            [], extra_seeds=["jaclang.data.storage.sqlalchemy_memory"]
        );
    }
    assert "sqlalchemy_memory" in str(exc.value);
}


test "denied extra seed fails loudly" {
    # The compiler tree resolves on disk but is deny-listed; an explicit
    # request for it is a configuration error, not something to skip.
    with testraises(ValueError) as exc {
        build_runtime_closure([], extra_seeds=["jaclang.compiler"]);
    }
    assert "jaclang.compiler" in str(exc.value);
}


test "legacy eject db drivers are rejected with a diagnostic" {
    compiled = [
        {
            "module": "app",
            "orig": "app",
            "py": "def foo():\n    return 1\n",
            "server": True
        }
    ];
    for driver in ["sqlite", "sql", "sqlalchemy", "mongo", "redis"] {
        tmp = Path(tempfile.mkdtemp());
        rc = emit_backend(
            tmp / "backend",
            "demo",
            compiled,
            [],
            [],
            {},
            {"driver": driver},
            [],
            False,
            ""
        );
        assert rc == 1 , f"driver {driver!r} must be rejected at eject time";
        assert not (tmp / "backend" / "main.py").exists() , f"driver {driver!r} must fail before emitting a backend";
    }
}
