"""`get_persistent_memory` L3-backend seam (#6619, piece 2b).

`get_persistent_memory` is a plain direct method on the runtime interface: core
`TieredMemory._resolve_l3_backend` consults `JacRuntimeInterface.get_persistent_memory`
before falling back to `SqliteMemory`, so a returned backend wins and `None`
(the core default) falls through unchanged. A custom L3 backend is injected via
`set_persistent_memory_provider` (used by ejected standalone backends); the
method can also be swapped at the class level (as the second test does).
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang { JacRuntimeInterface }
import from jaclang.runtimelib.memory { SqliteMemory, TieredMemory }


test "get_persistent_memory exists as a direct method on the runtime interface" {
    # A plain direct method on the interface (not a plugin hook); without the
    # declaration this attribute is absent.
    assert callable(JacRuntimeInterface?.get_persistent_memory) , (
        "JacRuntimeInterface must expose a get_persistent_memory method"
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
