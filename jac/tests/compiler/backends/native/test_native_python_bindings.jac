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
