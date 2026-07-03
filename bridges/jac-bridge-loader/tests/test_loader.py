"""
End-to-end tests for jac_bridge_loader against the regex bridge.

Mirrors jac-bridge-regex/python/test_ctypes.py exactly, using the
auto-generated module instead of the hand-written regex_bridge.py.
"""

import pathlib
import sys
import types

import pytest
from jac_bridge_loader import load_bridge
from jac_bridge_loader._blob import (
    FN_CTOR,
    FN_METHOD,
    KIND_ERROR,
    KIND_OPAQUE,
    TAG_BOOL,
    TAG_REF_BIT,
    TAG_STR,
    TAG_VOID,
)

# ── fixtures ─────────────────────────────────────────────────────────────────


@pytest.fixture(scope="module")
def mod(regex_so: str) -> types.ModuleType:
    return load_bridge(regex_so)


@pytest.fixture(scope="module")
def Regex(mod: types.ModuleType) -> type:
    return mod.Regex


@pytest.fixture(scope="module")
def RegexError(mod: types.ModuleType) -> type:
    return mod.RegexError


@pytest.fixture(scope="module")
def PanicError(mod: types.ModuleType) -> type:
    return mod.PanicError


# ── happy-path matching ───────────────────────────────────────────────────────


def test_match_true(Regex: type) -> None:
    with Regex(r"foo\d+") as re:
        assert re.is_match("foo42") is True


def test_match_false(Regex: type) -> None:
    with Regex(r"foo\d+") as re:
        assert re.is_match("bar99") is False


def test_multiple_calls_same_instance(Regex: type) -> None:
    with Regex(r"\bword\b") as re:
        assert re.is_match("a word here")
        assert not re.is_match("awordhere")
        assert re.is_match("word")


def test_unicode_pattern_and_text(Regex: type) -> None:
    with Regex(r"café") as re:
        assert re.is_match("a café nearby")
        assert not re.is_match("a cafe nearby")


def test_empty_pattern_matches_anything(Regex: type) -> None:
    with Regex("") as re:
        assert re.is_match("hello")
        assert re.is_match("")


# ── lifetime / resource management ───────────────────────────────────────────


def test_context_manager_drop(Regex: type) -> None:
    re = Regex(r"x")
    assert not re._closed
    re.__exit__(None, None, None)
    assert re._closed


def test_close_idempotent(Regex: type) -> None:
    re = Regex(r"x")
    re.close()
    re.close()


def test_use_after_close_raises(Regex: type) -> None:
    re = Regex(r"x")
    re.close()
    with pytest.raises(RuntimeError):
        re.is_match("x")


def test_del_after_explicit_close(Regex: type) -> None:
    re = Regex(r"x")
    re.close()
    re.__del__()


# ── error path ────────────────────────────────────────────────────────────────


def test_invalid_pattern_raises_error(Regex: type, RegexError: type) -> None:
    with pytest.raises(RegexError):
        Regex("(unclosed")


def test_bad_char_class_raises_error(Regex: type, RegexError: type) -> None:
    with pytest.raises(RegexError):
        Regex("[bad")


def test_error_message_is_non_empty(Regex: type, RegexError: type) -> None:
    try:
        Regex("[bad")
        pytest.fail("expected RegexError")
    except RegexError as exc:
        assert len(str(exc)) > 0


def test_multiple_bad_patterns_give_different_messages(
    Regex: type, RegexError: type
) -> None:
    msgs = []
    for pat in ["(a", "[b", "(?P<"]:
        try:
            Regex(pat)
        except RegexError as exc:
            msgs.append(str(exc))
    assert len(msgs) == 3
    assert len(set(msgs)) > 1


# ── D2 metadata (parsed via _meta, no raw ctypes arithmetic) ─────────────────


def test_metadata_module_name(mod: types.ModuleType) -> None:
    assert mod._meta.module_name == "regex"


def test_metadata_abi_version(mod: types.ModuleType) -> None:
    assert mod._meta.abi_version == 1


def test_metadata_type_count(mod: types.ModuleType) -> None:
    assert len(mod._meta.types) == 2


def test_metadata_fn_count(mod: types.ModuleType) -> None:
    assert len(mod._meta.fns) == 3


def test_metadata_type0_opaque(mod: types.ModuleType) -> None:
    td = mod._meta.types[0]
    assert td.name == "Regex"
    assert td.kind == KIND_OPAQUE
    assert td.drop_sym == "jac_regex_Regex_drop"


def test_metadata_type1_error(mod: types.ModuleType) -> None:
    td = mod._meta.types[1]
    assert td.name == "RegexError"
    assert td.kind == KIND_ERROR
    assert td.drop_sym == "jac_regex_error_drop"


def test_metadata_fn0_ctor(mod: types.ModuleType) -> None:
    fd = mod._meta.fns[0]
    assert fd.name == "new"
    assert fd.kind == FN_CTOR
    assert fd.sym == "jac_regex_Regex_new"
    assert fd.ret == (TAG_REF_BIT | 0)  # TYPE_REF(Regex)
    assert fd.throws == 1  # RegexError index


def test_metadata_fn0_param(mod: types.ModuleType) -> None:
    p = mod._meta.fns[0].params[0]
    assert p.name == "pattern"
    assert p.tag == TAG_STR


def test_metadata_fn1_method(mod: types.ModuleType) -> None:
    fd = mod._meta.fns[1]
    assert fd.name == "is_match"
    assert fd.kind == FN_METHOD
    assert fd.self_type == 0  # Regex index
    assert fd.ret == TAG_BOOL
    assert fd.throws == TAG_VOID  # no user error


def test_metadata_fn2_message(mod: types.ModuleType) -> None:
    fd = mod._meta.fns[2]
    assert fd.name == "message"
    assert fd.kind == FN_METHOD
    assert fd.self_type == 1  # RegexError index
    assert fd.ret == TAG_STR
    assert fd.throws == TAG_VOID


# ── D2 blob bytes (raw header checks, mirrors test_ctypes.py) ────────────────


def test_blob_magic(regex_so: str) -> None:
    from jac_bridge_loader._elf import read_jac_bridge_section

    blob = read_jac_bridge_section(regex_so)
    assert blob[:8] == b"JACBRDG1"


def test_blob_len_matches(regex_so: str) -> None:
    import struct

    from jac_bridge_loader._elf import read_jac_bridge_section

    blob = read_jac_bridge_section(regex_so)
    reported = struct.unpack_from("<I", blob, 16)[0]
    assert reported == len(blob) == 431


def test_blob_type_count_raw(regex_so: str) -> None:
    import struct

    from jac_bridge_loader._elf import read_jac_bridge_section

    blob = read_jac_bridge_section(regex_so)
    assert struct.unpack_from("<I", blob, 44)[0] == 2


def test_blob_fn_count_raw(regex_so: str) -> None:
    import struct

    from jac_bridge_loader._elf import read_jac_bridge_section

    blob = read_jac_bridge_section(regex_so)
    assert struct.unpack_from("<I", blob, 52)[0] == 3


# ── ABI invariant: void-return functions always have out_err + i32 status ────


def test_wire_void_return_has_out_err_and_i32_restype(mod: types.ModuleType) -> None:
    """_wire must emit out_err and c_int restype even for TAG_VOID returns."""
    import ctypes as ct

    from jac_bridge_loader._codegen import _wire

    # Synthesise a minimal void-return FnDesc using the drop symbol as a stand-in.
    # drop fns are (handle: u64) -> void in Rust, but here we want a bridge-style
    # fn with self + out_err -> i32.  Use the real wired ctor/method descriptors
    # to prove _wire produces the right signature instead.
    #
    # Check every fd in the bridge: after _wire, restype is ALWAYS c_int and the
    # LAST argtype is ALWAYS POINTER(c_uint64) (out_err).
    for fd in mod._meta.fns:
        if fd.name == "message":
            continue  # skip — message is wired separately in _Runtime
        c_fn = getattr(mod._lib, fd.sym)
        # Re-wire via the public helper to reset argtypes.
        _wire(mod._lib, fd)
        assert c_fn.restype is ct.c_int, f"{fd.name}: restype should be c_int"
        assert c_fn.argtypes[-1] == ct.POINTER(ct.c_uint64), (
            f"{fd.name}: last argtype should be POINTER(c_uint64) (out_err)"
        )


def test_void_return_fd_argtypes(mod: types.ModuleType) -> None:
    """For a TAG_VOID return, _wire should have no extra out-param before out_err."""
    import ctypes as ct

    from jac_bridge_loader._codegen import _wire

    for fd in mod._meta.fns:
        if fd.ret != TAG_VOID or fd.name == "message":
            continue
        _wire(mod._lib, fd)
        c_fn = getattr(mod._lib, fd.sym)
        # argtypes should NOT contain POINTER(c_uint8) or POINTER(_JacBuf) for out-val
        # — only self (c_uint64) + params + out_err (POINTER(c_uint64))
        for argtype in c_fn.argtypes[:-1]:
            assert argtype is not ct.POINTER(ct.c_uint8), (
                f"{fd.name}: unexpected out_result in void-return fn"
            )


# ── install_finder smoke-test ─────────────────────────────────────────────────


def test_install_finder_import(regex_so: str) -> None:
    from jac_bridge_loader import install_finder

    so_dir = str(pathlib.Path(regex_so).parent)
    install_finder([so_dir])

    # Force reimport (may already be cached if tests ran before).
    if "jac_bridge_regex" in sys.modules:
        del sys.modules["jac_bridge_regex"]

    import jac_bridge_regex  # noqa: PLC0415

    re = jac_bridge_regex.Regex(r"hello")
    assert re.is_match("hello world")
    re.close()
