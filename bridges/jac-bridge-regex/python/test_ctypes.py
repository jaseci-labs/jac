"""
Integration tests for the ctypes twin (python/regex_bridge.py).

Run from the jac-bridge-regex/ directory:
    cargo build --release && python -m pytest python/test_ctypes.py -v

Or from anywhere:
    cd bridges/jac-bridge-regex && cargo build --release
    python -m pytest python/test_ctypes.py -v
"""

import ctypes
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))

import pytest
from regex_bridge import Regex, RegexError, _JacBuf, _load

# --------------------------------------------------------------------------- #
# Happy-path matching
# --------------------------------------------------------------------------- #


def test_match_true():
    with Regex(r"foo\d+") as re:
        assert re.is_match("foo42") is True


def test_match_false():
    with Regex(r"foo\d+") as re:
        assert re.is_match("bar99") is False


def test_multiple_calls_same_instance():
    with Regex(r"\bword\b") as re:
        assert re.is_match("a word here")
        assert not re.is_match("awordhere")
        assert re.is_match("word")


def test_unicode_pattern_and_text():
    with Regex(r"café") as re:
        assert re.is_match("a café nearby")
        assert not re.is_match("a cafe nearby")


def test_empty_pattern_matches_anything():
    with Regex("") as re:
        assert re.is_match("hello")
        assert re.is_match("")


# --------------------------------------------------------------------------- #
# Lifetime / resource management
# --------------------------------------------------------------------------- #


def test_context_manager_drop():
    re = Regex(r"x")
    assert not re._closed
    re.__exit__(None, None, None)
    assert re._closed


def test_close_idempotent():
    re = Regex(r"x")
    re.close()
    re.close()  # must not double-free or crash


def test_use_after_close_raises():
    re = Regex(r"x")
    re.close()
    with pytest.raises(RuntimeError):
        re.is_match("x")


def test_del_after_explicit_close():
    re = Regex(r"x")
    re.close()
    re.__del__()  # GC fires after explicit close — must be a no-op


# --------------------------------------------------------------------------- #
# Error path
# --------------------------------------------------------------------------- #


def test_invalid_pattern_raises_regex_error():
    with pytest.raises(RegexError):
        Regex("(unclosed")


def test_bad_char_class_raises_regex_error():
    with pytest.raises(RegexError):
        Regex("[bad")


def test_error_message_is_non_empty():
    try:
        Regex("[bad")
        pytest.fail("expected RegexError")
    except RegexError as exc:
        assert len(str(exc)) > 0, "error message must not be empty"


def test_multiple_bad_patterns_independent_errors():
    msgs = []
    for pat in ["(a", "[b", "(?P<"]:
        try:
            Regex(pat)
        except RegexError as exc:
            msgs.append(str(exc))
    assert len(msgs) == 3
    assert len(set(msgs)) > 1, "different bad patterns should give different messages"


# --------------------------------------------------------------------------- #
# D2 metadata via init pointer (cross-compile simulation, no dlopen internals)
# --------------------------------------------------------------------------- #


def test_metadata_magic():
    lib = _load()
    ptr = lib.jac_bridge_init_regex()
    blob = (ctypes.c_uint8 * 8).from_address(ptr)
    assert bytes(blob) == b"JACBRDG1"


def test_metadata_abi_version():
    lib = _load()
    ptr = lib.jac_bridge_init_regex()
    blob = (ctypes.c_uint8 * 12).from_address(ptr)
    v = int.from_bytes(bytes(blob)[8:12], "little")
    assert v == 1


def test_metadata_blob_len():
    lib = _load()
    ptr = lib.jac_bridge_init_regex()
    blob = (ctypes.c_uint8 * 20).from_address(ptr)
    reported_len = int.from_bytes(bytes(blob)[16:20], "little")
    assert reported_len == 431


def test_metadata_type_count():
    lib = _load()
    ptr = lib.jac_bridge_init_regex()
    blob = (ctypes.c_uint8 * 56).from_address(ptr)
    types_count = int.from_bytes(bytes(blob)[44:48], "little")
    assert types_count == 2  # Regex + RegexError


def test_metadata_fn_count():
    lib = _load()
    ptr = lib.jac_bridge_init_regex()
    blob = (ctypes.c_uint8 * 56).from_address(ptr)
    fns_count = int.from_bytes(bytes(blob)[52:56], "little")
    assert fns_count == 3  # new + is_match + message


def test_metadata_module_name():
    lib = _load()
    ptr = lib.jac_bridge_init_regex()
    blob = (ctypes.c_uint8 * 431).from_address(ptr)
    raw = bytes(blob)
    off = int.from_bytes(raw[24:28], "little")
    length = int.from_bytes(raw[28:32], "little")
    assert raw[off : off + length] == b"regex"


def test_metadata_drop_symbol_regex():
    lib = _load()
    ptr = lib.jac_bridge_init_regex()
    blob = (ctypes.c_uint8 * 431).from_address(ptr)
    raw = bytes(blob)
    # TypeDesc[0] at byte 56; drop_symbol StrRef at td0+16
    td0 = 56
    off = int.from_bytes(raw[td0 + 16 : td0 + 20], "little")
    length = int.from_bytes(raw[td0 + 20 : td0 + 24], "little")
    assert raw[off : off + length] == b"jac_regex_Regex_drop"


def test_metadata_fn0_ret_is_type_ref_0():
    lib = _load()
    ptr = lib.jac_bridge_init_regex()
    blob = (ctypes.c_uint8 * 431).from_address(ptr)
    raw = bytes(blob)
    # FnDesc[0] at byte 120; ret TypeTag at fd0+32
    fd0 = 120
    ret = int.from_bytes(raw[fd0 + 32 : fd0 + 36], "little")
    assert ret == 0x8000_0000  # TYPE_REF(0) = Regex


# --------------------------------------------------------------------------- #
# JacBuf allocation and free
# --------------------------------------------------------------------------- #


def test_error_message_buf_freed_without_crash():
    lib = _load()
    import ctypes as ct

    enc = b"[bad"
    out_h = ct.c_uint64(0)
    out_e = ct.c_uint64(0)
    lib.jac_regex_Regex_new(enc, len(enc), ct.byref(out_h), ct.byref(out_e))
    assert out_e.value != 0

    buf1 = _JacBuf()
    buf2 = _JacBuf()
    tmp = ct.c_uint64(0)
    lib.jac_regex_error_message(out_e.value, ct.byref(buf1), ct.byref(tmp))
    lib.jac_regex_error_message(out_e.value, ct.byref(buf2), ct.byref(tmp))
    msg = ct.string_at(buf1.ptr, buf1.len).decode()
    assert len(msg) > 0
    lib.jac_regex_free_buf(buf1)
    lib.jac_regex_free_buf(buf2)
    lib.jac_regex_error_drop(out_e.value)
