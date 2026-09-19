"""Hosted native stdlib feasibility probe, used by scripts/probe_native_stdlib.py.

Object handles borrow their inputs and return a new reference, or zero with
the CPython exception still set. The caller must hold the GIL. In particular,
these exports accept PyObject handles, not native Jac strings or containers.
The Python driver uses PyDLL and explicitly consumes each returned reference.
"""

import from c {
    def PyImport_Import(name: u64) -> u64;
    def PyObject_GetAttr(value: u64, name: u64) -> u64;
    def PyObject_Call(value: u64, args: u64, kwargs: u64) -> u64;
    def Py_DecRef(value: u64);
}

def:pub import_call(module_name: u64, name: u64, args: u64, kwargs: u64) -> u64 {
    mod = PyImport_Import(module_name);
    if mod == 0 { return 0; }
    fn = PyObject_GetAttr(mod, name);
    Py_DecRef(mod);
    if fn == 0 { return 0; }
    result = PyObject_Call(fn, args, kwargs);
    Py_DecRef(fn);
    return result;
}

def:pub method_call(value: u64, name: u64, args: u64, kwargs: u64) -> u64 {
    fn = PyObject_GetAttr(value, name);
    if fn == 0 { return 0; }
    result = PyObject_Call(fn, args, kwargs);
    Py_DecRef(fn);
    return result;
}

import from c {
    def PyTuple_New(size: i64) -> u64;
    def PyTuple_SetItem(value: u64, index: i64, item: u64) -> i32;
    def PyTuple_GetItem(value: u64, index: i64) -> u64;
    def PyUnicode_FromString(value: str) -> u64;
    def PyLong_AsLongLong(value: u64) -> i64;
    def PyErr_Occurred -> u64;
}

def single_text(value: str) -> u64 {
    item = PyUnicode_FromString(value);
    if item == 0 { return 0; }
    args = PyTuple_New(i64(1));
    if args == 0 {
        Py_DecRef(item);
        return 0;
    }
    if PyTuple_SetItem(args, i64(0), item) != 0 {
        Py_DecRef(args);
        return 0;
    }
    return args;
}

def:pub native_sqlite_answer(value: i64) -> i64 {
    args = single_text(":memory:");
    if args == 0 { return i64(-1); }
    connection = import_named("sqlite3", "connect", args, u64(0));
    Py_DecRef(args);
    if connection == 0 { return i64(-1); }
    query = single_text("select " + str(value) + " + 1");
    if query == 0 {
        Py_DecRef(connection);
        return i64(-1);
    }
    cursor = method_named(connection, "execute", query, u64(0));
    Py_DecRef(query);
    if cursor == 0 {
        Py_DecRef(connection);
        return i64(-1);
    }
    empty = PyTuple_New(i64(0));
    if empty == 0 {
        Py_DecRef(cursor);
        Py_DecRef(connection);
        return i64(-1);
    }
    row = method_named(cursor, "fetchone", empty, u64(0));
    Py_DecRef(cursor);
    if row == 0 {
        Py_DecRef(empty);
        Py_DecRef(connection);
        return i64(-1);
    }
    cell = PyTuple_GetItem(row, i64(0));
    if cell == 0 {
        Py_DecRef(row);
        Py_DecRef(empty);
        Py_DecRef(connection);
        return i64(-1);
    }
    answer = PyLong_AsLongLong(cell);
    Py_DecRef(row);
    if PyErr_Occurred() != 0 {
        Py_DecRef(empty);
        Py_DecRef(connection);
        return i64(-1);
    }
    closed = method_named(connection, "close", empty, u64(0));
    Py_DecRef(empty);
    Py_DecRef(connection);
    if closed == 0 { return i64(-1); }
    Py_DecRef(closed);
    return answer;
}


def import_named(module_name: str, name: str, args: u64, kwargs: u64) -> u64 {
    mod = PyUnicode_FromString(module_name);
    if mod == 0 { return 0; }
    attr = PyUnicode_FromString(name);
    if attr == 0 { Py_DecRef(mod); return 0; }
    result = import_call(mod, attr, args, kwargs);
    Py_DecRef(attr);
    Py_DecRef(mod);
    return result;
}

def method_named(value: u64, name: str, args: u64, kwargs: u64) -> u64 {
    attr = PyUnicode_FromString(name);
    if attr == 0 { return 0; }
    result = method_call(value, attr, args, kwargs);
    Py_DecRef(attr);
    return result;
}
