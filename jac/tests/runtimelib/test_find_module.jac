"""Regression tests for `JacProgram.find_module` -- the single, program-spanning
resolver for "the compiled module at <path>".

`_resolve_program` routes a file to either the user's program (`Jac.program`) or
the compiler's internal program (anything under the jaclang package root, e.g.
the bundled `jac ai --ui` app). A consumer that holds only a path -- the server's
auth/manifest introspection, the client bundler -- must resolve the module no
matter which program owns it. Before `find_module`, those consumers read
`Jac.program.mod.hub` directly and silently missed internal-program modules,
which made every `def:pub` endpoint of a jaclang-bundled app return 401.
"""

import os;
import shutil;
import jaclang;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.runtime { JacRuntime as Jac }

"""Write a `.jac` file under the jaclang package root, so `_resolve_program`
routes it to the internal program (the `jac ai --ui` condition). Returns the
created directory (caller rmtrees it) and the file path."""
def _bundled_app(slug: str, body: str) -> tuple[Path, Path] {
    d = Path(jaclang.__file__).parent / f"_find_module_test_{slug}";
    d.mkdir(exist_ok=True);
    f = d / "bundled_app.jac";
    f.write_text(body);
    return (d, f);
}

test "find_module resolves a module routed to the internal program" {
    (d, f) = _bundled_app("resolve", 'def:pub greet() -> str { return "hi"; }\n');
    key = str(f.resolve());
    try {
        mod = Jac.program.compile(key);
        assert mod is not None;
        # The divergence the bug relied on: a jaclang-root file is routed to the
        # internal program, so it never lands in the user program's hub.
        assert key not in Jac.program.mod.hub;
        # ...but find_module spans the internal program and resolves it.
        assert Jac.program.find_module(key) is mod;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "find_module resolves a user-program module and returns None for unknown" {
    with TemporaryDirectory() as tmp {
        f = Path(tmp) / "user.jac";
        f.write_text('def:pub f() -> int { return 1; }\n');
        key = str(f.resolve());
        mod = Jac.program.compile(key);
        # A user-dir module lands in the user program and resolves there.
        assert Jac.program.find_module(key) is mod;
        assert Jac.program.find_module(str(Path(tmp) / "nope.jac")) is None;
    }
}

test "public endpoints of a jaclang-bundled app do not require auth" {
    import from jaclang.runtimelib.server { ModuleIntrospector }

    (d, f) = _bundled_app(
        "auth",
        'def:pub open_ep() -> int { return 1; }\n'
        'def guarded_ep() -> int { return 2; }\n'
    );
    try {
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
