"""Ordinary Python imports use retained CPython objects in native control flow."""
import ctypes;
import sqlite3;
import sys;
import from tests.support { compile_native, get_func }

test "ordinary imports preserve object protocols and original Python errors" {
    (engine, module) = compile_native("python_imports.jac");
    assert engine.requires_python;
    assert module.gen.llvm_ir is not None;
    for (name, expected) in [("answer", 42), ("aliased", 17), ("large_integer", 201)] {
        call = get_func(engine, name, ctypes.c_int64);
        assert call() == expected;
    }
    caught = get_func(engine, "caught", ctypes.c_int64);
    failed = get_func(engine, "failed", ctypes.c_int64);
    overflowing = get_func(engine, "overflowing_integer", ctypes.c_int64);
    module_references = sys.getrefcount(sqlite3);
    for _ in range(100) {
        assert caught() == 7;
        try {
            failed();
            assert False , "native call lost the Python exception";
        } except sqlite3.OperationalError as error {
            assert "missing_column" in str(error);
        }
        try {
            overflowing();
            assert False , "native scalar conversion must check overflow";
        } except OverflowError {}
    }
    assert sys.getrefcount(sqlite3) == module_references;
}
