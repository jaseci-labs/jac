# M3 CPython consumer tests: `import rust.regex { Regex }` end to end.
#
# The finder is pointed at the cargo target dir via JAC_RUST_BRIDGES_PATH so the
# tests are hermetic and don't depend on a populated ~/.cache/jac layout.
import gc;
import sys;
import os;
import importlib;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { SUPPORTED_ABI, install_rust_namespace }
import jaclang.compiler.rust_bridge._importer as _imp;
import from _fixtures { regex_so }


# -- rust_ns fixture, hand-rolled ----------------------------------------------
def _regex_dir -> str {
    return str(Path(regex_so()).parent);
}


def _strip_finders {
    # Strip by class *name*, not identity: an in-process `import jaclang` in an
    # earlier test auto-installs jaclang's OWN, distinct `RustBridgeFinder` onto
    # sys.meta_path. Remove any same-named finder from either package.
    sys.meta_path[:] = [
        f
        for f in sys.meta_path
        if type(f).__name__ != "RustBridgeFinder"
    ];
}


def _clear_rust_modules {
    for name in [
        n
        for n in sys.modules
        if n == "rust" or n.startswith("rust.")
    ] {
        del sys.modules[name];
    }
}


def _setup_rust_ns -> object {
    _old = os.environ.get("JAC_RUST_BRIDGES_PATH");
    os.environ["JAC_RUST_BRIDGES_PATH"] = _regex_dir();
    _clear_rust_modules();
    _strip_finders();
    install_rust_namespace();
    return _old;
}


def _teardown_rust_ns(_old: object) {
    _clear_rust_modules();
    _strip_finders();
    if _old is None {
        os.environ.pop("JAC_RUST_BRIDGES_PATH", None);
    } else {
        os.environ["JAC_RUST_BRIDGES_PATH"] = _old;
    }
}


glob _real_parse = _imp.parse;


def _fake_parse(blob: bytes) -> object {
    meta = _real_parse(blob);
    meta.abi_version = SUPPORTED_ABI + 1;
    return meta;
}


# -- tests ---------------------------------------------------------------------
test "import rust regex" {
    _old = _setup_rust_ns();
    try {
        rr = importlib.import_module("rust.regex");
        re = rr.Regex(r"foo\d+");
        assert re.is_match("foo42");
        assert not re.is_match("bar99");
        re.close();
    } finally {
        _teardown_rust_ns(_old);
    }
}


test "from import class" {
    _old = _setup_rust_ns();
    try {
        mod = importlib.import_module("rust.regex");
        regex_cls = mod.Regex;
        with regex_cls(r"\d+") as re {
            assert re.is_match("abc123");
        }
    } finally {
        _teardown_rust_ns(_old);
    }
}


test "bad pattern raises named error" {
    _old = _setup_rust_ns();
    try {
        rr = importlib.import_module("rust.regex");
        _RegexError = rr.RegexError;
        raised = False;
        try {
            rr.Regex("(unclosed");
        } except _RegexError {
            raised = True;
        }
        assert raised;
    } finally {
        _teardown_rust_ns(_old);
    }
}


test "rust is namespace package" {
    _old = _setup_rust_ns();
    try {
        rust_mod = importlib.import_module("rust");
        assert rust_mod.__name__ == "rust";
    } finally {
        _teardown_rust_ns(_old);
    }
}


test "missing crate is import error" {
    _old = _setup_rust_ns();
    try {
        raised = False;
        try {
            importlib.import_module("rust.no_such_crate_xyz");
        } except ImportError {
            raised = True;
        }
        assert raised;
    } finally {
        _teardown_rust_ns(_old);
    }
}


test "finalizer drops without explicit close" {
    # D3: GC alone must drop the handle exactly once via weakref.finalize.
    _old = _setup_rust_ns();
    try {
        rr = importlib.import_module("rust.regex");
        re = rr.Regex("abc");
        fin = re._finalizer;
        assert fin.alive;
        del re;
        gc.collect();
        assert not fin.alive;  # finalizer ran exactly once at GC
    } finally {
        _teardown_rust_ns(_old);
    }
}


test "close detaches finalizer" {
    # close() must drop and mark the finalizer dead so GC can't double-drop.
    _old = _setup_rust_ns();
    try {
        rr = importlib.import_module("rust.regex");
        re = rr.Regex("abc");
        fin = re._finalizer;
        re.close();
        assert not fin.alive;
        re.close();  # idempotent
        assert not fin.alive;
    } finally {
        _teardown_rust_ns(_old);
    }
}


test "supported abi is one" {
    assert SUPPORTED_ABI == 1;
}


test "unsupported abi fails closed" {
    # D2: a bridge declaring a newer ABI must fail closed with a readable error,
    # never a segfault or a misparse.
    _old = _setup_rust_ns();
    _imp.parse = _fake_parse;
    try {
        raised = False;
        try {
            importlib.import_module("rust.regex");
        } except ImportError as exc {
            raised = True;
            assert "ABI version" in str(exc);
        }
        assert raised;
    } finally {
        _imp.parse = _real_parse;
        _teardown_rust_ns(_old);
    }
}
