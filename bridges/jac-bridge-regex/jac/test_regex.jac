import ctypes;
import from regex { Regex, RegexError, _JacBuf, _load_lib }


test "match true" {
    with Regex(r"foo\d+") as re {
        assert re.is_match("foo42") is True;
    }
}

test "match false" {
    with Regex(r"foo\d+") as re {
        assert re.is_match("bar99") is False;
    }
}

test "multiple calls same instance" {
    with Regex(r"\bword\b") as re {
        assert re.is_match("a word here");
        assert not re.is_match("awordhere");
        assert re.is_match("word");
    }
}

test "unicode pattern and text" {
    with Regex(r"café") as re {
        assert re.is_match("a café nearby");
        assert not re.is_match("a cafe nearby");
    }
}

test "empty pattern matches anything" {
    with Regex("") as re {
        assert re.is_match("hello");
        assert re.is_match("");
    }
}


test "context manager drop" {
    re = Regex(r"x");
    assert not re._closed;
    re.__exit__(None, None, None);
    assert re._closed;
}

test "close idempotent" {
    re = Regex(r"x");
    re.close();
    re.close();
}

test "use after close raises" {
    re = Regex(r"x");
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
    re = Regex(r"x");
    re.close();
    re.__del__();
}


test "invalid pattern raises regex error" {
    raised = False;
    try {
        Regex("(unclosed");
    } except RegexError {
        raised = True;
    }
    assert raised;
}

test "bad char class raises regex error" {
    raised = False;
    try {
        Regex("[bad");
    } except RegexError {
        raised = True;
    }
    assert raised;
}

test "error message is non-empty" {
    raised = False;
    try {
        Regex("[bad");
    } except RegexError as exc {
        raised = True;
        assert len(str(exc)) > 0 , "error message must not be empty";
    }
    assert raised;
}

test "multiple bad patterns independent errors" {
    msgs = [];
    for pat in ["(a", "[b", "(?P<"] {
        try {
            Regex(pat);
        } except RegexError as exc {
            msgs.append(str(exc));
        }
    }
    assert len(msgs) == 3;
    assert len(set(msgs)) > 1 , "different bad patterns should give different messages";
}


test "metadata magic" {
    lib = _load_lib();
    ptr = lib.jac_bridge_init_regex();
    blob = (ctypes.c_uint8 * 8).from_address(ptr);
    assert bytes(blob) == b"JACBRDG1";
}

test "metadata abi version" {
    lib = _load_lib();
    ptr = lib.jac_bridge_init_regex();
    blob = (ctypes.c_uint8 * 12).from_address(ptr);
    v = int.from_bytes(bytes(blob)[8:12], "little");
    assert v == 1;
}

test "metadata blob len" {
    lib = _load_lib();
    ptr = lib.jac_bridge_init_regex();
    blob = (ctypes.c_uint8 * 20).from_address(ptr);
    reported_len = int.from_bytes(bytes(blob)[16:20], "little");
    assert reported_len == 431;
}

test "metadata type count" {
    lib = _load_lib();
    ptr = lib.jac_bridge_init_regex();
    blob = (ctypes.c_uint8 * 56).from_address(ptr);
    types_count = int.from_bytes(bytes(blob)[44:48], "little");
    assert types_count == 2;
}

test "metadata fn count" {
    lib = _load_lib();
    ptr = lib.jac_bridge_init_regex();
    blob = (ctypes.c_uint8 * 56).from_address(ptr);
    fns_count = int.from_bytes(bytes(blob)[52:56], "little");
    assert fns_count == 3;
}

test "metadata module name" {
    lib = _load_lib();
    ptr = lib.jac_bridge_init_regex();
    blob = (ctypes.c_uint8 * 431).from_address(ptr);
    raw = bytes(blob);
    off = int.from_bytes(raw[24:28], "little");
    length = int.from_bytes(raw[28:32], "little");
    assert raw[off:off + length] == b"regex";
}

test "metadata drop symbol regex" {
    lib = _load_lib();
    ptr = lib.jac_bridge_init_regex();
    blob = (ctypes.c_uint8 * 431).from_address(ptr);
    raw = bytes(blob);
    td0 = 56;
    off = int.from_bytes(raw[td0 + 16:td0 + 20], "little");
    length = int.from_bytes(raw[td0 + 20:td0 + 24], "little");
    assert raw[off:off + length] == b"jac_regex_Regex_drop";
}

test "metadata fn0 ret is type ref 0" {
    lib = _load_lib();
    ptr = lib.jac_bridge_init_regex();
    blob = (ctypes.c_uint8 * 431).from_address(ptr);
    raw = bytes(blob);
    fd0 = 120;
    ret = int.from_bytes(raw[fd0 + 32:fd0 + 36], "little");
    assert ret == 0x80000000;
}


test "error message buf freed without crash" {
    lib = _load_lib();
    enc = b"[bad";
    out_h = ctypes.c_uint64(0);
    out_e = ctypes.c_uint64(0);
    lib.jac_regex_Regex_new(enc, len(enc), ctypes.byref(out_h), ctypes.byref(out_e));
    assert out_e.value != 0;

    buf1 = _JacBuf();
    buf2 = _JacBuf();
    tmp = ctypes.c_uint64(0);
    lib.jac_regex_error_message(out_e.value, ctypes.byref(buf1), ctypes.byref(tmp));
    lib.jac_regex_error_message(out_e.value, ctypes.byref(buf2), ctypes.byref(tmp));
    msg = ctypes.string_at(buf1.ptr, buf1.len).decode();
    assert len(msg) > 0;
    lib.jac_regex_free_buf(buf1);
    lib.jac_regex_free_buf(buf2);
    lib.jac_regex_error_drop(out_e.value);
}
