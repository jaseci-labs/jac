"""`get_persistent_memory` plugin hookspec (#6619, piece 2b).

Every Jac runtime hook is `firstresult`, so two plugins implementing
`create_j_context` conflict rather than compose -- a third-party DB backend
(e.g. `jac-postgres`) would have to clone jac-scale's whole-context approach
and be mutually exclusive with jac-scale. This additive hookspec shrinks a
backend to a `PersistentMemory` subclass plus one hookimpl: core
`TieredMemory.postinit` consults the hook before falling back to
`SqliteMemory`, so a returned backend wins and `None` (the core default)
falls through unchanged.

On `main` the hookspec does not exist and `postinit` never consults it, so
both assertions below fail.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang { JacRuntimeInterface }
import from jaclang.runtimelib.memory { SqliteMemory, TieredMemory }


test "the get_persistent_memory hookspec exists on the runtime interface" {
    # The proxy/hookspec is generated from JacRuntimeInterface's static
    # methods; without the declaration this attribute is absent.
    assert callable(JacRuntimeInterface?.get_persistent_memory) , (
        "JacRuntimeInterface must expose a get_persistent_memory hook"
    );
}


test "TieredMemory.postinit uses a hook-provided L3 backend, else SqliteMemory" {
    with TemporaryDirectory() as raw_tmpdir {
        tmpdir = str(raw_tmpdir);
        # A plugin-supplied backend the hook will hand back.
        sentinel = SqliteMemory(path=str(Path(tmpdir) / "sentinel.db"));
        captured: list = [];
        original = JacRuntimeInterface.get_persistent_memory;
        try {
            JacRuntimeInterface.get_persistent_memory = (
                lambda config : (captured.append(config) or sentinel)
            );
            tm = TieredMemory(
                base_path=tmpdir, target_path=str(Path(tmpdir) / "hooked.jac")
            );
            assert tm.l3 is sentinel , (
                "postinit must install the hook-provided PersistentMemory as L3"
            );
            assert captured , "postinit must call the hook with a config dict";
            assert isinstance(captured[0], dict);
        } finally {
            JacRuntimeInterface.get_persistent_memory = original;
        }
        # With the hook returning None (the core default), L3 falls back to
        # the built-in SqliteMemory exactly as before.
        tm2 = TieredMemory(
            base_path=tmpdir, target_path=str(Path(tmpdir) / "fallback.jac")
        );
        assert isinstance(tm2.l3, SqliteMemory) , (
            "absent a plugin backend, L3 must remain SqliteMemory"
        );
    }
}
