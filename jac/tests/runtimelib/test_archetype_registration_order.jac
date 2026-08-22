"""Archetype registration must not depend on module import order.

`Archetype._subclass_hooks` is only consulted by `__init_subclass__`, so a hook
installed at time T used to see nothing that existed before T. When the
serializer's registration hook landed after an application's node/edge classes
were created, those classes were never registered and every read of their
anchors was refused and dropped, which reads back to the caller as "no such
record". These tests pin both halves of the fix: hook installation back-fills
the existing subclass tree, and resolution falls back to the class's own module
so an unregistered-but-resolvable archetype is never refused.
"""

import importlib;
import os;
import shutil;
import sys;
import from tempfile { mkdtemp }
import from types { ModuleType }
import from uuid { uuid4 }
import from jaclang.jac0core.archetype { Archetype, NodeAnchor, Root }
import from jaclang.runtimelib { serializer as serializer_mod }
import from jaclang.runtimelib.serializer { Serializer }

glob ATTEMPTS = "JAC_8117_IMPORT_ATTEMPTS",
     FAIL = "JAC_8117_FAIL_IMPORT";


obj _EarlyNode(Root) {
    has name: str = "";
}


obj _EarlyChild(_EarlyNode) {
    has extra: int = 0;
}


def _key(cls: type) -> str {
    return f"{cls.__module__}.{cls.__name__}";
}


def _publish_home_module -> (object | None) {
    # The jac test collector imports a test file twice, so the module object
    # sitting in sys.modules under this file's name is not the one whose
    # classes are running here, and resolution would hand back a same-named
    # twin. Publish the live classes under their own module name for the
    # duration of a test, which is what an ordinary application module that
    # defines archetypes looks like to the runtime.
    shim = ModuleType(_EarlyNode.__module__);
    setattr(shim, '_EarlyNode', _EarlyNode);
    setattr(shim, '_EarlyChild', _EarlyChild);
    previous = sys.modules.get(_EarlyNode.__module__);
    sys.modules[_EarlyNode.__module__] = shim;
    return previous;
}


def _restore_home_module(previous: (object | None)) {
    if previous is None {
        sys.modules.pop(_EarlyNode.__module__, None);
    } else {
        sys.modules[_EarlyNode.__module__] = previous;
    }
}


def _anchor_blob(arch: object) -> dict {
    raw = Serializer.serialize(arch, include_type=True);
    return {
        '__type__': 'NodeAnchor',
        '__module__': 'jaclang.jac0core.archetype',
        'id': str(uuid4()),
        'root': None,
        'persistent': False,
        'access': {'all': -1, 'roots': {'anchors': {}}},
        'archetype': raw,
        'edges': [],
        'version': 0
    };
}


# --- Back-fill on hook install ---------------------------------------------
test "installing a hook back-fills archetype classes that already exist" {
    seen: list = [];

    def recorder(cls: type) {
        seen.append(_key(cls));
    }
    Archetype.install_subclass_hook(recorder);
    try {
        # Both classes above were created long before this hook existed.
        assert _key(_EarlyNode) in seen , (
            f"hook did not back-fill a pre-existing class: {len(seen)} seen"
        );
        # ...including one that is a subclass of a subclass (transitive walk).
        assert _key(_EarlyChild) in seen , "back-fill did not walk the whole tree";
        # Framework base classes are skipped, exactly as __init_subclass__ does.
        assert _key(Root) not in seen , "__jac_base__ classes must stay excluded";
    } finally {
        Archetype.uninstall_subclass_hook(recorder);
    }
}


test "installing the same hook twice neither duplicates it nor re-runs it" {
    calls: list = [];

    def recorder(cls: type) {
        calls.append(cls);
    }
    Archetype.install_subclass_hook(recorder);
    first_pass = len(calls);
    hook_count = len(Archetype._subclass_hooks);
    Archetype.install_subclass_hook(recorder);
    try {
        assert first_pass > 0 , "back-fill saw no existing archetype classes";
        assert len(calls) == first_pass , "re-installing a hook re-ran the back-fill";
        assert len(Archetype._subclass_hooks) == hook_count , (
            "re-installing a hook appended a duplicate"
        );
    } finally {
        Archetype.uninstall_subclass_hook(recorder);
    }
}


test "an installed hook still fires for classes created afterwards" {
    seen: list = [];

    def recorder(cls: type) {
        seen.append(cls.__name__);
    }
    Archetype.install_subclass_hook(recorder);
    try {
        late = type("_LateNode", (_EarlyNode, ), {'__annotations__': {}});
        assert "_LateNode" in seen , (
            "install_subclass_hook broke the forward path of __init_subclass__"
        );
        assert late is not None;
    } finally {
        Archetype.uninstall_subclass_hook(recorder);
    }
}


test "a raw append cannot install a hook that skips the back-fill" {
    # install_subclass_hook appends *and* back-fills. While the hook list stays
    # a plain mutable list on a public-looking class attribute, the next caller
    # who reaches for `.append` silently reintroduces #8049: their hook only
    # ever sees classes created after it, so everything defined earlier goes
    # unregistered and every read of those anchors is refused and dropped.
    seen: list = [];

    def recorder(cls: type) {
        seen.append(cls);
    }
    installed = False;
    try {
        Archetype._subclass_hooks.append(recorder);
        installed = True;
    } except AttributeError { } finally {
        if installed {
            try {
                Archetype._subclass_hooks.remove(recorder);
            } except Exception { }
        }
    }
    assert not installed , (
        "a raw append still installs a hook, so the next caller can skip the "
        "back-fill without hearing about it"
    );
    assert seen == [] , "a refused append must not have run the hook either";
}


test "uninstall_subclass_hook removes a hook and is safe to repeat" {
    calls: list = [];

    def recorder(cls: type) {
        calls.append(cls);
    }
    Archetype.install_subclass_hook(recorder);
    installed_count = len(Archetype._subclass_hooks);
    Archetype.uninstall_subclass_hook(recorder);
    assert len(Archetype._subclass_hooks) == installed_count - 1 , (
        "uninstall_subclass_hook did not remove the hook"
    );
    # Removing something that is not installed is a no-op, not an error.
    Archetype.uninstall_subclass_hook(recorder);
    assert len(Archetype._subclass_hooks) == installed_count - 1;
    before = len(calls);
    type("_UninstalledProbe", (_EarlyNode, ), {'__annotations__': {}});
    assert len(calls) == before , "an uninstalled hook still fired";
}


# --- Order-independent resolution ------------------------------------------
test "an anchor whose class is not registered round-trips instead of dropping" {
    original = _EarlyNode(name="visible");
    blob = _anchor_blob(original);
    key = _key(_EarlyNode);
    # Exactly the state a class lands in when it is created before the
    # serializer's hook is installed: the class object exists, the registry
    # has never heard of it.
    saved = Serializer._registry.pop(key, None);
    previous_home = _publish_home_module();
    Serializer._reset_warn_cache();
    try {
        anchor = Serializer.deserialize(blob);
        assert anchor is not None , (
            "a resolvable archetype was refused and its anchor dropped"
        );
        assert isinstance(anchor, NodeAnchor);
        arch = anchor.archetype;
        assert type(arch) is _EarlyNode , f"wrong class rehydrated: {type(arch)}";
        assert getattr(arch, 'name') == "visible";
        # Resolution self-heals the registry, so the next read is a plain hit.
        assert Serializer._registry.get(key) is _EarlyNode , (
            "resolved class was not registered for subsequent reads"
        );
    } finally {
        _restore_home_module(previous_home);
        if saved is not None {
            Serializer._registry[key] = saved;
        }
        Serializer._reset_warn_cache();
    }
}


test "_get_class resolves an unregistered archetype from its own module" {
    key = _key(_EarlyChild);
    saved = Serializer._registry.pop(key, None);
    previous_home = _publish_home_module();
    Serializer._reset_warn_cache();
    try {
        resolved = Serializer._get_class(_EarlyChild.__module__, "_EarlyChild");
        assert resolved is _EarlyChild , (
            f"resolution refused a live class: {resolved}"
        );
    } finally {
        _restore_home_module(previous_home);
        if saved is not None {
            Serializer._registry[key] = saved;
        }
        Serializer._reset_warn_cache();
    }
}


# --- The allowlist still refuses everything that is not an archetype -------
test "resolution refuses names that are not archetype classes" {
    Serializer._reset_warn_cache();
    try {
        assert Serializer._get_class("os", "system") is None , (
            "callables must never resolve"
        );
        assert Serializer._get_class("builtins", "dict") is None , (
            "non-archetype types must never resolve"
        );
        # Every Jac `obj` is an Archetype subclass, so the runtime's own
        # internals are archetypes too. Auto-registration deliberately skips
        # `jaclang.*` (except `jaclang.scale.*`) and resolution honors the same
        # line: a runtime-internal class resolves only if it was registered
        # explicitly, exactly as before this fallback existed.
        assert not Serializer.is_auto_registered_module(
            "jaclang.runtimelib.serializer"
        );
        assert Serializer.is_auto_registered_module("jaclang.scale.something");
        assert Serializer.is_auto_registered_module("myapp.nodes");
        assert Serializer._get_class("jaclang.runtimelib.serializer", "Serializer")
            is None , "runtime-internal archetypes must not resolve implicitly";
        assert Serializer._get_class("os", "does_not_exist") is None;
        assert Serializer._get_class("definitely.not", "Present") is None;
    } finally {
        Serializer._reset_warn_cache();
    }
}


test "deserialize still refuses a non-archetype class named in the payload" {
    Serializer._reset_warn_cache();
    try {
        assert Serializer.deserialize(
            {'__type__': 'dict', '__module__': 'builtins', 'a': 1}
        )
            is None;
    } finally {
        Serializer._reset_warn_cache();
    }
}


test "resolution never imports a module whose package the process never loaded" {
    tmp = mkdtemp();
    mod_name = "jac8049_untrusted";
    marker = "JAC_8049_UNTRUSTED_RAN";
    with open(os.path.join(tmp, f"{mod_name}.py"), "w") as fh {
        fh.write(f"import os\nos.environ[{marker!r}] = '1'\n");
    }
    sys.path.insert(0, tmp);
    Serializer._reset_warn_cache();
    try {
        assert mod_name not in sys.modules;
        assert Serializer._get_class(mod_name, "Ghost") is None;
        assert mod_name not in sys.modules , (
            "resolution imported a module the payload merely named"
        );
        assert os.environ.get(marker) is None , (
            "resolution executed module-level code from an untrusted name"
        );
    } finally {
        if tmp in sys.path {
            sys.path.remove(tmp);
        }
        os.environ.pop(marker, None);
        shutil.rmtree(tmp, ignore_errors=True);
        Serializer._reset_warn_cache();
    }
}


test "resolution does load a submodule of a package the process already uses" {
    # The other side of the same gate: a lazily loaded submodule of a package
    # the application itself imported is inside the trust boundary, so a stored
    # anchor whose class lives there is still resolvable.
    tmp = mkdtemp();
    pkg_name = "jac8049_app";
    marker = "JAC_8049_APP_SUBMODULE_RAN";
    pkg_dir = os.path.join(tmp, pkg_name);
    os.makedirs(pkg_dir);
    with open(os.path.join(pkg_dir, "__init__.py"), "w") as fh {
        fh.write("");
    }
    with open(os.path.join(pkg_dir, "nodes.py"), "w") as fh {
        fh.write(f"import os\nos.environ[{marker!r}] = '1'\n");
    }
    sys.path.insert(0, tmp);
    Serializer._reset_warn_cache();
    try {
        importlib.import_module(pkg_name);
        assert os.environ.get(marker) is None , "submodule loaded too early";
        # No such class, so resolution still refuses, but the gate let the
        # import through because the top-level package was already loaded.
        assert Serializer._get_class(f"{pkg_name}.nodes", "Ghost") is None;
        assert os.environ.get(marker) == "1" , (
            "resolution did not load the submodule of an already-loaded package"
        );
    } finally {
        if tmp in sys.path {
            sys.path.remove(tmp);
        }
        for loaded in list(sys.modules.keys()) {
            if loaded == pkg_name or loaded.startswith(f"{pkg_name}.") {
                sys.modules.pop(loaded, None);
            }
        }
        os.environ.pop(marker, None);
        shutil.rmtree(tmp, ignore_errors=True);
        Serializer._reset_warn_cache();
    }
}


# --- An import failure is transient, not a life sentence --------------------
"""Write a package whose submodule counts its own executions and raises while
JAC_8117_FAIL_IMPORT is set, which is what a module caught half-initialised by
a circular import under concurrency looks like to an importer."""
def _flaky_package(pkg_name: str) -> str {
    tmp = mkdtemp();
    pkg_dir = os.path.join(tmp, pkg_name);
    os.makedirs(pkg_dir);
    with open(os.path.join(pkg_dir, "__init__.py"), "w") as fh {
        fh.write("");
    }
    with open(os.path.join(pkg_dir, "nodes.py"), "w") as fh {
        fh.write(
            "import os\n"
            f"os.environ[{ATTEMPTS!r}] = str(int(os.environ.get({ATTEMPTS!r}, '0')) + 1)\n"
            f"if os.environ.get({FAIL!r}) == '1':\n"
            "    raise RuntimeError('module is only half initialised')\n"
        );
    }
    sys.path.insert(0, tmp);
    importlib.import_module(pkg_name);
    return tmp;
}


def _attempts -> int {
    return int(os.environ.get(ATTEMPTS, "0"));
}


def _forget_package(tmp: str, pkg_name: str) {
    if tmp in sys.path {
        sys.path.remove(tmp);
    }
    for loaded in list(sys.modules.keys()) {
        if loaded == pkg_name or loaded.startswith(f"{pkg_name}.") {
            sys.modules.pop(loaded, None);
        }
    }
    os.environ.pop(ATTEMPTS, None);
    os.environ.pop(FAIL, None);
    shutil.rmtree(tmp, ignore_errors=True);
    Serializer._reset_warn_cache();
    Serializer._reset_import_failures();
}


test "a module that failed to import once is retried later" {
    pkg_name = "jac8117_retry";
    mod_name = f"{pkg_name}.nodes";
    tmp = _flaky_package(pkg_name);
    saved_window = serializer_mod._IMPORT_RETRY_SECONDS;
    os.environ[FAIL] = "1";
    Serializer._reset_warn_cache();
    try {
        assert Serializer._get_class(mod_name, "Ghost") is None;
        assert _attempts() == 1 , f"the module never ran: {_attempts()} attempts";
        # The cache still earns its keep: a hot read path must not re-attempt
        # the import (and re-scan sys.path) on every single anchor.
        assert Serializer._get_class(mod_name, "Ghost") is None;
        assert _attempts() == 1 , (
            f"the failure was not remembered at all: {_attempts()} attempts"
        );
        # The race that caused the failure is over: the module imports cleanly
        # now, and once the retry window has passed resolution must try again
        # rather than treat those anchors as gone for the life of the process.
        os.environ[FAIL] = "0";
        serializer_mod._IMPORT_RETRY_SECONDS = 0.0;
        Serializer._get_class(mod_name, "Ghost");
        assert _attempts() == 2 , (
            "a module that failed to import once is never retried, so every "
            "anchor whose class lives there stays invisible until a restart"
        );
    } finally {
        serializer_mod._IMPORT_RETRY_SECONDS = saved_window;
        _forget_package(tmp, pkg_name);
    }
}


test "a module that shows up in sys.modules clears its failure record" {
    pkg_name = "jac8117_reappear";
    mod_name = f"{pkg_name}.nodes";
    tmp = _flaky_package(pkg_name);
    os.environ[FAIL] = "1";
    Serializer._reset_warn_cache();
    try {
        assert Serializer._get_class(mod_name, "Ghost") is None;
        assert _attempts() == 1;
        # Exactly what the losing thread of a circular-import race sees a
        # moment later: the module it could not import is in sys.modules, put
        # there by the thread that won.
        sys.modules[mod_name] = ModuleType(mod_name);
        assert Serializer._get_class(mod_name, "Ghost") is None;
        assert _attempts() == 1 , "a module already in sys.modules was re-imported";
        # Whatever removed it (a reload, a teardown) leaves resolution free to
        # import it again: the recorded failure went away when the module did
        # not, so no retry window applies here.
        sys.modules.pop(mod_name, None);
        os.environ[FAIL] = "0";
        Serializer._get_class(mod_name, "Ghost");
        assert _attempts() == 2 , (
            "the failure record outlived the failure: the module was importable "
            "and present in sys.modules, and resolution still refused to look"
        );
    } finally {
        _forget_package(tmp, pkg_name);
    }
}
