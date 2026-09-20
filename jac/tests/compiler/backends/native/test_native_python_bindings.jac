"""Hosted imports bind at the statement and follow resolved symbol identity."""
import ctypes;
import sqlite3;
import sys;
import types;
import from tests.support { compile_native, get_func }

test "Python import aliases are scoped and local imports execute once" {
    (engine, _) = compile_native("python_import_bindings.jac");
    assert get_func(engine, "add", ctypes.c_int64)() == 10;
    assert get_func(engine, "subtract", ctypes.c_int64)() == 4;
    local = get_func(engine, "local_binding", ctypes.c_bool);
    unused = get_func(engine, "unused_binding", ctypes.c_int64);
    calls: list[str] = [];
    def attribute(name: str) -> any {
        if name != "sqlite_version" {
            raise AttributeError(name);
        }
        calls.append(name);
        return object();
    }
    replacement = types.ModuleType("sqlite3");
    setattr(replacement, "__getattr__", attribute);
    original = sys.modules[sqlite3.__name__];
    try {
        sys.modules["sqlite3"] = replacement;
        assert local();
        assert unused() == 42;
        assert calls == ["sqlite_version", "sqlite_version"];
        delattr(replacement, "__getattr__");
        try {
            unused();
            assert False , "an unused from import must still resolve its member";
        } except ImportError as error {
            assert "sqlite_version" in str(error);
        }
    } finally {
        sys.modules["sqlite3"] = original;
    }
}

test "module imports initialize eagerly and preserve distinct alias bindings" {
    (engine, _) = compile_native("python_module_bindings.jac");
    calls: list[str] = [];
    def attribute(name: str) -> any {
        if name != "sqlite_version" {
            raise AttributeError(name);
        }
        calls.append(name);
        return object();
    }
    replacement = types.ModuleType("sqlite3");
    setattr(replacement, "__getattr__", attribute);
    original = sys.modules[sqlite3.__name__];
    try {
        sys.modules["sqlite3"] = replacement;
        unused = get_func(engine, "unused", ctypes.c_int64);
        assert unused() == 42;
        assert calls == ["sqlite_version", "sqlite_version"];
        stable = get_func(engine, "stable", ctypes.c_bool);
        aliases = get_func(engine, "aliases", ctypes.c_bool);
        delattr(replacement, "__getattr__");
        for _ in range(100) {
            assert stable();
            assert not aliases();
        }
        assert len(calls) == 2;
    } finally {
        sys.modules["sqlite3"] = original;
    }
}

test "failed module imports roll back and retry without retaining partial bindings" {
    (engine, _) = compile_native("python_module_bindings.jac");
    sentinel = object();
    baseline = sys.getrefcount(sentinel);
    calls: list[str] = [];
    def attribute(name: str) -> any {
        if name != "sqlite_version" or calls {
            raise AttributeError(name);
        }
        calls.append(name);
        return sentinel;
    }
    replacement = types.ModuleType("sqlite3");
    setattr(replacement, "__getattr__", attribute);
    original = sys.modules[sqlite3.__name__];
    try {
        sys.modules["sqlite3"] = replacement;
        try {
            get_func(engine, "unused", ctypes.c_int64)();
            assert False , "unused module imports must execute before native entry";
        } except ImportError as error {
            assert "sqlite_version" in str(error);
        }
        assert sys.getrefcount(sentinel) == baseline;
        setattr(replacement, "sqlite_version", 17);
        number = get_func(engine, "number", ctypes.c_int64);
        assert number() == 17;
        setattr(replacement, "sqlite_version", 99);
        assert number() == 17;
    } finally {
        sys.modules["sqlite3"] = original;
    }
}

test "native module bindings belong to each interpreter" {
    import _interpreters;
    (engine, _) = compile_native("python_module_bindings.jac");
    original = sys.modules[sqlite3.__name__];
    replacement = types.ModuleType("sqlite3");
    setattr(replacement, "sqlite_version", 17);
    try {
        sys.modules["sqlite3"] = replacement;
        number = get_func(engine, "number", ctypes.c_int64);
        assert number() == 17;
        address = engine.get_function_address("number");
        for expected in [23, 42] {
            interpreter = _interpreters.create("legacy");
            try {
                failure = _interpreters.run_string(
                    interpreter,
                    "import ctypes, sys, types\n"
                    "replacement = types.ModuleType('sqlite3')\n"
                    f"replacement.sqlite_version = {expected}\n"
                    "sys.modules['sqlite3'] = replacement\n"
                    f"number = ctypes.PYFUNCTYPE(ctypes.c_int64)({address})\n"
                    f"assert number() == {expected}\n"
                    "replacement.sqlite_version = 99\n"
                    f"assert number() == {expected}\n"
                );
                assert failure is None , str(failure);
            } finally {
                _interpreters.destroy(interpreter);
            }
            assert number() == 17;
        }
    } finally {
        sys.modules["sqlite3"] = original;
    }
}

test "concurrent and recursive native entry reuse Python module locks" {
    import from concurrent.futures { ThreadPoolExecutor }
    import from threading { Event }
    (engine, _) = compile_native("python_module_bindings.jac");
    replacement = types.ModuleType("sqlite3");
    original = sys.modules[sqlite3.__name__];
    try {
        sys.modules["sqlite3"] = replacement;
        engine.static_init_symbols = [];
        unused = get_func(engine, "unused", ctypes.c_int64);
        number = get_func(engine, "number", ctypes.c_int64);
        entered = Event();
        release = Event();
        second_started = Event();
        calls: list[str] = [];
        def attribute(name: str) -> int {
            if name != "sqlite_version" {
                raise AttributeError(name);
            }
            calls.append(name);
            assert unused() == 42;
            entered.set();
            assert release.wait(10);
            return 17;
        }
        def second -> int {
            second_started.set();
            return number();
        }
        setattr(replacement, "__getattr__", attribute);
        with ThreadPoolExecutor(max_workers=2) as pool {
            first = pool.submit(number);
            try {
                assert entered.wait(10);
                other = pool.submit(second);
                assert second_started.wait(10);
                try {
                    other.result(timeout=0.05);
                    assert False , "second native entry observed a partial module";
                } except TimeoutError {}
            } finally {
                release.set();
            }
            assert first.result(timeout=10) == 17;
            assert other.result(timeout=10) == 17;
        }
        assert calls == ["sqlite_version", "sqlite_version"];
    } finally {
        sys.modules["sqlite3"] = original;
    }
}
