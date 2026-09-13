"""Compiled modules have one explicit program owner, including bundled apps."""

import os;
import shutil;
import jaclang;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.runtime { JacRuntime as Jac }

"""Create a temporary bundled application fixture."""
def _bundled_app(slug: str, body: str) -> tuple[Path, Path] {
    d = Path(jaclang.__file__).parent / f"_find_module_test_{slug}";
    d.mkdir(exist_ok=True);
    f = d / "bundled_app.jac";
    f.write_text(body);
    return (d, f);
}

test "find_module resolves a bundled module in its explicit program" {
    (d, f) = _bundled_app("resolve", 'def:pub greet() -> str { return "hi"; }\n');
    key = str(f.resolve());
    prog = Jac.program;
    assert prog is not None;
    try {
        mod = prog.compile(key);
        assert mod is not None;
        assert prog.mod.hub[key] is mod;
        assert prog.find_module(key) is mod;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "find_module resolves a user-program module and returns None for unknown" {
    with TemporaryDirectory() as tmp {
        f = Path(tmp) / "user.jac";
        f.write_text('def:pub f() -> int { return 1; }\n');
        key = str(f.resolve());
        prog = Jac.program;
        assert prog is not None;
        mod = prog.compile(key);
        # A user-dir module lands in the user program and resolves there.
        assert prog.find_module(key) is mod;
        assert prog.find_module(str(Path(tmp) / "nope.jac")) is None;
    }
}

test "public endpoints of a jaclang-bundled app do not require auth" {
    import from jaclang.server.server { ModuleIntrospector }

    (d, f) = _bundled_app(
        "auth",
        'def:pub open_ep() -> int { return 1; }\n'
        'def guarded_ep() -> int { return 2; }\n'
    );
    try {
        import from jaclang.compiler.driver.application { prepare_application }
        prepare_application(str(f), Jac.get_program(), str(d));
        intro = ModuleIntrospector("bundled_app", str(d));
        intro.load();
        # `def:pub` -> public (no auth); a bare `def` -> secure by default. Before
        # the fix the introspector bailed (module absent from Jac.program.mod.hub)
        # and left every function auth-required, returning 401 on `def:pub` calls.
        assert intro.is_auth_required_for_function("open_ep") == False;
        assert intro.is_auth_required_for_function("guarded_ep") == True;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
