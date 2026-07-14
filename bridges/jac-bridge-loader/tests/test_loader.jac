# End-to-end tests for the jac rust-bridge loader against the regex bridge.
# Mirrors jac-bridge-regex/jac test coverage, using the auto-generated module
# (load_bridge) instead of a hand-written binding.
import os;
import sys;
import struct;
import importlib;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { load_bridge, install_rust_namespace }
import from jaclang.compiler.rust_bridge._blob {
    FN_CTOR,
    FN_METHOD,
    KIND_ERROR,
    KIND_OPAQUE,
    TAG_BOOL,
    TAG_REF_BIT,
    TAG_STR,
    TAG_VOID
}
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._ctypes_codegen { _wire }
import from _fixtures { regex_so }


glob _SO = regex_so(),
     _MOD = load_bridge(_SO),
     _Regex = _MOD.Regex,
     _RegexError = _MOD.RegexError,
     _PanicError = _MOD.PanicError;


# -- happy-path matching -------------------------------------------------------
test "match true" {
    with _Regex(r"foo\d+") as re {
        assert re.is_match("foo42") is True;
    }
}

test "match false" {
    with _Regex(r"foo\d+") as re {
        assert re.is_match("bar99") is False;
    }
}

test "multiple calls same instance" {
    with _Regex(r"\bword\b") as re {
        assert re.is_match("a word here");
        assert not re.is_match("awordhere");
        assert re.is_match("word");
    }
}

test "unicode pattern and text" {
    with _Regex(r"café") as re {
        assert re.is_match("a café nearby");
        assert not re.is_match("a cafe nearby");
    }
}

test "empty pattern matches anything" {
    with _Regex("") as re {
        assert re.is_match("hello");
        assert re.is_match("");
    }
}


# -- lifetime / resource management --------------------------------------------
test "context manager drop" {
    re = _Regex(r"x");
    assert not re._closed;
    re.__exit__(None, None, None);
    assert re._closed;
}

test "close idempotent" {
    re = _Regex(r"x");
    re.close();
    re.close();
}

test "use after close raises" {
    re = _Regex(r"x");
    re.close();
    raised = False;
    try {
        re.is_match("x");
    } except RuntimeError {
        raised = True;
    }
    assert raised;
}

test "del after explicit close" {
    re = _Regex(r"x");
    re.close();
    re.__del__();
}


# -- error path ----------------------------------------------------------------
test "invalid pattern raises error" {
    raised = False;
    try {
        _Regex("(unclosed");
    } except _RegexError {
        raised = True;
    }
    assert raised;
}

test "bad char class raises error" {
    raised = False;
    try {
        _Regex("[bad");
    } except _RegexError {
        raised = True;
    }
    assert raised;
}

test "error message is non-empty" {
    raised = False;
    try {
        _Regex("[bad");
    } except _RegexError as exc {
        raised = True;
        assert len(str(exc)) > 0;
    }
    assert raised;
}

test "multiple bad patterns give different messages" {
    msgs = [];
    for pat in ["(a", "[b", "(?P<"] {
        try {
            _Regex(pat);
        } except _RegexError as exc {
            msgs.append(str(exc));
        }
    }
    assert len(msgs) == 3;
    assert len(set(msgs)) > 1;
}


# -- D2 metadata ---------------------------------------------------------------
test "metadata module name" {
    assert _MOD._meta.module_name == "regex";
}

test "metadata abi version" {
    assert _MOD._meta.abi_version == 1;
}

test "metadata type count" {
    assert len(_MOD._meta.types) == 2;
}

test "metadata fn count" {
    assert len(_MOD._meta.fns) == 3;
}

test "metadata type0 opaque" {
    td = _MOD._meta.types[0];
    assert td.name == "Regex";
    assert td.kind == KIND_OPAQUE;
    assert td.drop_sym == "jac_regex_Regex_drop";
}

test "metadata type1 error" {
    td = _MOD._meta.types[1];
    assert td.name == "RegexError";
    assert td.kind == KIND_ERROR;
    assert td.drop_sym == "jac_regex_error_drop";
}

test "metadata fn0 ctor" {
    fd = _MOD._meta.fns[0];
    assert fd.name == "new";
    assert fd.kind == FN_CTOR;
    assert fd.sym == "jac_regex_Regex_new";
    assert fd.ret == (TAG_REF_BIT | 0);
    assert fd.throws == 1;
}

test "metadata fn0 param" {
    p = _MOD._meta.fns[0].params[0];
    assert p.name == "pattern";
    assert p.tag == TAG_STR;
}

test "metadata fn1 method" {
    fd = _MOD._meta.fns[1];
    assert fd.name == "is_match";
    assert fd.kind == FN_METHOD;
    assert fd.self_type == 0;
    assert fd.ret == TAG_BOOL;
    assert fd.throws == TAG_VOID;
}

test "metadata fn2 message" {
    fd = _MOD._meta.fns[2];
    assert fd.name == "message";
    assert fd.kind == FN_METHOD;
    assert fd.self_type == 1;
    assert fd.ret == TAG_STR;
    assert fd.throws == TAG_VOID;
}


# -- D2 blob bytes (raw header checks) -----------------------------------------
test "blob magic" {
    blob = read_jac_bridge_section(_SO);
    assert blob[:8] == b"JACBRDG1";
}

test "blob len matches" {
    blob = read_jac_bridge_section(_SO);
    reported = struct.unpack_from("<I", blob, 16)[0];
    assert reported == len(blob);
    assert reported == 431;
}

test "blob type count raw" {
    blob = read_jac_bridge_section(_SO);
    assert struct.unpack_from("<I", blob, 44)[0] == 2;
}

test "blob fn count raw" {
    blob = read_jac_bridge_section(_SO);
    assert struct.unpack_from("<I", blob, 52)[0] == 3;
}


# -- ABI invariant: void-return fns always have out_err + i32 status -----------
test "wire void return has out_err and i32 restype" {
    import ctypes;
    for fd in _MOD._meta.fns {
        if fd.name == "message" {
            continue;
        }
        c_fn = getattr(_MOD._lib, fd.sym);
        _wire(_MOD._lib, fd);
        assert c_fn.restype is ctypes.c_int;
        assert c_fn.argtypes[-1] == ctypes.POINTER(ctypes.c_uint64);
    }
}

test "void return fd argtypes" {
    import ctypes;
    for fd in _MOD._meta.fns {
        if fd.ret != TAG_VOID or fd.name == "message" {
            continue;
        }
        _wire(_MOD._lib, fd);
        c_fn = getattr(_MOD._lib, fd.sym);
        for argtype in c_fn.argtypes[:-1] {
            assert argtype is not ctypes.POINTER(ctypes.c_uint8);
        }
    }
}


# -- install_rust_namespace smoke-test -----------------------------------------
test "install finder import" {
    so_dir = str(Path(_SO).parent);
    install_rust_namespace([so_dir]);

    if "jac_bridge_regex" in sys.modules {
        del sys.modules["jac_bridge_regex"];
    }

    jac_bridge_regex = importlib.import_module("jac_bridge_regex");
    re = jac_bridge_regex.Regex(r"hello");
    assert re.is_match("hello world");
    re.close();
}


# -- error-handle cleanup: drain_err must drop the handle even when the bridge's
#    own message() call fails (behavioral parity with the reference; the module
#    surface drift test cannot catch a leak on this path) ------------------------
test "drain_err drops the error handle when the message read fails" {
    import ctypes;
    lib = _MOD._lib;
    rt = _MOD._rt;

    # Obtain a real, live error handle from a bad pattern (the low-level ctor
    # writes the error box into out_e without draining it).
    enc = b"(unclosed";
    out_h = ctypes.c_uint64(0);
    out_e = ctypes.c_uint64(0);
    lib.jac_regex_Regex_new(enc, len(enc), ctypes.byref(out_h), ctypes.byref(out_e));
    err_h = out_e.value;
    assert err_h != 0;

    idx = [
        t.index
        for t in _MOD._meta.types
        if t.kind == KIND_ERROR
    ][0];

    real_drop = rt._err_drops[idx];
    real_msg = rt._err_msgs[idx];
    dropped = [];
    # Wrap the drop so we can observe it fire (and still free the handle), and
    # force the message() call to report failure so drain_err takes the early-out.
    rt._err_drops[idx] = lambda h : (dropped.append(h), real_drop(h));
    rt._err_msgs[idx] = lambda h , b , e : 2 ;
    try {
        msg = rt.drain_err(err_h, idx);
        assert "status=2" in msg;
        assert dropped == [err_h] , "error handle must be dropped on the message-read failure path (no leak)";
    } finally {
        rt._err_drops[idx] = real_drop;
        rt._err_msgs[idx] = real_msg;
        if not dropped {
            real_drop(err_h);
        }
    }
}


# -- universal panic plumbing: drain_panic reads the message AND frees the handle
#    via the dedicated panic symbols, independent of the #[jac_error] type. A
#    panic handle is a Box<String> exactly like an error handle, so a real error
#    box is a faithful stand-in for exercising the panic drain/free path. -------
test "drain_panic reads the message and drops the handle via panic symbols" {
    import ctypes;
    lib = _MOD._lib;
    rt = _MOD._rt;

    # The macro (and this reference bridge) emit these for every bridge.
    assert rt.panic_msg is not None , "bridge must export jac_<mod>_panic_message";
    assert rt.panic_drop is not None , "bridge must export jac_<mod>_panic_drop";

    # A live Box<String> handle (same representation as a panic handle).
    enc = b"(unclosed";
    out_h = ctypes.c_uint64(0);
    out_e = ctypes.c_uint64(0);
    lib.jac_regex_Regex_new(enc, len(enc), ctypes.byref(out_h), ctypes.byref(out_e));
    err_h = out_e.value;
    assert err_h != 0;

    real_pd = rt.panic_drop;
    dropped = [];
    rt.panic_drop = lambda h : (dropped.append(h), real_pd(h));
    try {
        msg = rt.drain_panic(err_h);
        # The real panic message is surfaced (not a generic status string).
        assert msg and "status=" not in msg;
        assert dropped == [err_h] , "panic handle must be freed by drain_panic (no leak)";
    } finally {
        rt.panic_drop = real_pd;
        if not dropped {
            real_pd(err_h);
        }
    }
}
