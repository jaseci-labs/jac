"""Ordinary Python imports use retained CPython objects in native control flow."""
import ctypes;
import sqlite3;
import sys;
import from tests.support { compile_native, get_func }

test "Python text and bytes conversions preserve content and reject wrong types" {
    (engine, _) = compile_native("python_scalar_buffers.jac", required=True);
    buffers = get_func(engine, "buffers", ctypes.c_bool);
    invalid = get_func(engine, "invalid", ctypes.c_bool, ctypes.c_bool);
    for _ in range(100) {
        assert buffers();
        for text in [True, False] {
            try {
                invalid(text);
                assert False , "a mismatched Python object must fail conversion";
            } except TypeError {}
        }
    }
}

test "ordinary imports preserve object protocols and original Python errors" {
    (engine, module) = compile_native("python_imports.jac", required=True);
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

test "Python values use runtime arithmetic identity membership and truth" {
    (engine, _) = compile_native("python_imports.jac", required=True);
    for name in ["arithmetic", "identity_and_truth", "membership", "short_circuit"] {
        call = get_func(engine, name, ctypes.c_bool);
        for _ in range(100) {
            assert call() , name;
        }
    }
    failed = get_func(engine, "comparison_error", ctypes.c_bool);
    try {
        failed();
        assert False , "rich comparison lost its Python exception";
    } except TypeError {}
}

test "Python iterators release values on exhaustion and early exit" {
    (engine, _) = compile_native("python_imports.jac", required=True);
    call = get_func(engine, "iterate", ctypes.c_int64, ctypes.c_bool);
    for _ in range(100) {
        assert call(False) == 42;
        assert call(True) == 17;
    }
}

test "Python iteration errors and builtin protocols preserve Python behavior" {
    (engine, _) = compile_native("python_imports.jac", required=True);
    protocols = get_func(engine, "builtin_protocols", ctypes.c_bool);
    failed = get_func(engine, "iterator_failure", ctypes.c_int64);
    for _ in range(100) {
        assert protocols();
        try {
            failed();
            assert False , "closed cursor iteration lost its Python error";
        } except sqlite3.ProgrammingError {}
    }
}
