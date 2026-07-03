"""OPT-bit (nullable Option<T>) return handling in the CPython loader.

The `owning` bridge (jac-bridge-owning) exercises every nullable shape the D2
ABI carries:
  * Regex.find      -> Option<Ref>  (OwnedMatch handle, or None)
  * Regex.captures  -> Option<Ref>  (OwnedCaptures handle, or None)
  * OwnedCaptures.name -> Option<Str>  (matched group text, or None)

None crosses in-band on an OK status — a null handle for Option<Ref>, a null
JacBuf.ptr for Option<Str> — and the loader must map it to Python `None`, not a
zero handle or an empty string.
"""

import types

import pytest
from jac_bridge_loader import load_bridge
from jac_bridge_loader._blob import TAG_OPT_BIT, TAG_REF_BIT, TAG_STR

# ── fixtures ─────────────────────────────────────────────────────────────────


@pytest.fixture(scope="module")
def mod(owning_so: str) -> types.ModuleType:
    return load_bridge(owning_so)


@pytest.fixture(scope="module")
def Regex(mod: types.ModuleType) -> type:
    return mod.Regex


# ── metadata: the OPT bit is set on exactly the nullable returns ─────────────


def test_find_ret_is_opt_ref(mod: types.ModuleType) -> None:
    fd = next(f for f in mod._meta.fns if f.name == "find")
    assert fd.ret & TAG_OPT_BIT, "find must set TAG_OPT_BIT"
    assert fd.ret & TAG_REF_BIT, "find must set TAG_REF_BIT (Option<Ref>)"


def test_name_ret_is_opt_str(mod: types.ModuleType) -> None:
    fd = next(f for f in mod._meta.fns if f.name == "name")
    assert fd.ret == (TAG_OPT_BIT | TAG_STR), "name must be Option<Str>"


def test_as_str_ret_is_plain_str(mod: types.ModuleType) -> None:
    # The non-nullable reader must NOT carry the OPT bit.
    fd = next(f for f in mod._meta.fns if f.name == "as_str")
    assert fd.ret == TAG_STR


# ── Option<Ref>: find returns a handle on a match, None otherwise ────────────


def test_find_match_returns_wrapper(Regex: type) -> None:
    with Regex(r"\d+") as re:
        m = re.find("abc123def")
        assert m is not None
        assert m.as_str() == "123"
        m.close()


def test_find_no_match_returns_none(Regex: type) -> None:
    with Regex(r"\d+") as re:
        assert re.find("no digits here") is None


def test_find_empty_match_is_not_none(Regex: type) -> None:
    # An empty (zero-width) match is a real match — must be a handle, not None.
    with Regex(r"") as re:
        m = re.find("anything")
        assert m is not None
        assert m.as_str() == ""
        m.close()


def test_returned_wrapper_is_a_context_manager(Regex: type) -> None:
    with Regex(r"\w+") as re, re.find("hello") as m:
        assert m.as_str() == "hello"


def test_returned_wrapper_drops_cleanly(Regex: type) -> None:
    # No explicit close: GC/finalizer path must drop the wrapper handle.
    with Regex(r"\d+") as re:
        for _ in range(200):
            m = re.find("x1")
            assert m.as_str() == "1"
            # deliberately drop the reference without close()


# ── Option<Ref>: captures behaves the same ───────────────────────────────────


def test_captures_no_match_returns_none(Regex: type) -> None:
    with Regex(r"(\d+)-(\d+)") as re:
        assert re.captures("nothing") is None


# ── Option<Str>: OwnedCaptures.name yields text or None ──────────────────────


def test_named_group_present_returns_str(Regex: type) -> None:
    with Regex(r"(?P<year>\d{4})") as re:
        caps = re.captures("in 2026 today")
        assert caps is not None
        assert caps.name("year") == "2026"
        caps.close()


def test_named_group_absent_returns_none(Regex: type) -> None:
    # Group exists in the pattern but a non-matching alternation branch means it
    # did not participate -> Option<Str> None, distinct from an empty string.
    with Regex(r"(?P<a>x)|(?P<b>y)") as re:
        caps = re.captures("y")
        assert caps is not None
        assert caps.name("a") is None  # 'a' did not participate
        assert caps.name("b") == "y"
        caps.close()


def test_unknown_group_name_returns_none(Regex: type) -> None:
    with Regex(r"(?P<g>\d+)") as re:
        caps = re.captures("42")
        assert caps is not None
        assert caps.name("nonexistent") is None
        caps.close()
