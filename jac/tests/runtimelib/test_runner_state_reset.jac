"""Unit tests for the per-test state reset in the jac test runner."""

import from dataclasses { dataclass }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.test_runner { _detach_from_parent, _fresh_jac_state }
import from jaclang.runtimelib.typecache { get_field_types }


@dataclass
class _Ghost {
    name: str = "";
}


@dataclass
class _Keeper {
    name: str = "";
}


test "unregister_module drops only the named module's classes" {
    _Ghost.__module__ = "jac_ghost_mod";
    _Keeper.__module__ = "jac_keeper_mod";
    Serializer.register(_Ghost);
    Serializer.register(_Keeper);
    assert "jac_ghost_mod._Ghost" in Serializer._registry;
    assert "jac_keeper_mod._Keeper" in Serializer._registry;
    dropped = Serializer.unregister_module("jac_ghost_mod");
    assert dropped == 1;
    assert "jac_ghost_mod._Ghost" not in Serializer._registry;
    assert "jac_keeper_mod._Keeper" in Serializer._registry;
    Serializer.unregister_module("jac_keeper_mod");
}


test "unregister_module clears aliases pointing at the dropped classes" {
    _Ghost.__module__ = "jac_ghost_mod";
    Serializer.register(_Ghost);
    Serializer.register_alias("legacy.Ghost", _Ghost);
    assert Serializer._aliases.get("legacy.Ghost") == "jac_ghost_mod._Ghost";
    Serializer.unregister_module("jac_ghost_mod");
    assert "legacy.Ghost" not in Serializer._aliases;
}


test "unregister_module releases the class's cached field types" {
    _Ghost.__module__ = "jac_ghost_mod";
    Serializer.register(_Ghost);
    get_field_types(_Ghost);
    import from jaclang.runtimelib.typecache { _cache }
    assert _Ghost in _cache;
    Serializer.unregister_module("jac_ghost_mod");
    assert _Ghost not in _cache;
}


test "unregister_module on an unknown module is a no-op" {
    before = len(Serializer._registry);
    assert Serializer.unregister_module("jac_module_that_never_was") == 0;
    assert len(Serializer._registry) == before;
}


test "a fresh runner state shuts down the executor it replaces" {
    _fresh_jac_state(clear_modules=False);
    replaced = JacRuntime.pool;
    _fresh_jac_state(clear_modules=False);
    assert JacRuntime.pool is not replaced;
    try {
        replaced.submit(len, "x");
        assert False , "the replaced pool still accepts work";
    } except RuntimeError {
        ;
    }
}


test "detaching a submodule releases it from its parent package" {
    import sys;
    import types;
    parent = types.ModuleType("jac_parent_pkg");
    child = types.ModuleType("jac_parent_pkg.child");
    child.BULK = [0] * 1000;
    parent.child = child;
    sys.modules["jac_parent_pkg"] = parent;
    sys.modules["jac_parent_pkg.child"] = child;
    sys.modules.pop("jac_parent_pkg.child", None);
    assert parent.child is child;
    _detach_from_parent("jac_parent_pkg.child");
    assert not hasattr(parent, "child");
    sys.modules.pop("jac_parent_pkg", None);
}


test "detaching tolerates a missing parent or attribute" {
    _detach_from_parent("jac_absent_pkg.child");
    _detach_from_parent("no_dots_at_all");
    _detach_from_parent("");
}
