"""M3 CPython consumer tests: `import rust.regex { Regex }` end to end.

The finder is pointed at the cargo target dir via JAC_RUST_BRIDGES_PATH so the
tests are hermetic and don't depend on a populated ~/.cache/jac layout.
"""

import gc
import importlib
import sys
from collections.abc import Iterator

import pytest
from jac_bridge_loader._blob import BridgeMeta
from jac_bridge_loader.rust_namespace import (
    SUPPORTED_ABI,
    install_rust_namespace,
)


@pytest.fixture()
def rust_ns(regex_so: str, monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Install the rust. finder pointed at the dir holding libjac_bridge_regex."""
    import pathlib

    monkeypatch.setenv("JAC_RUST_BRIDGES_PATH", str(pathlib.Path(regex_so).parent))

    # Strip by class *name*, not identity: an in-process `import jaclang` in an
    # earlier test (e.g. test_cache_install) auto-installs jaclang's OWN, distinct
    # `RustBridgeFinder` onto sys.meta_path. It would resolve rust.* before this
    # package's finder with its own unpatched parse() — silently defeating the
    # ABI-gate monkeypatch below. Remove any same-named finder from either package.
    def _strip_finders() -> None:
        sys.meta_path[:] = [
            f for f in sys.meta_path if type(f).__name__ != "RustBridgeFinder"
        ]

    # Clear any previously imported rust.* modules and stale finders.
    for name in [n for n in sys.modules if n == "rust" or n.startswith("rust.")]:
        del sys.modules[name]
    _strip_finders()
    install_rust_namespace()
    yield
    for name in [n for n in sys.modules if n == "rust" or n.startswith("rust.")]:
        del sys.modules[name]
    _strip_finders()


def test_import_rust_regex(rust_ns: None) -> None:
    import rust.regex  # noqa: F401

    re = rust.regex.Regex(r"foo\d+")
    assert re.is_match("foo42")
    assert not re.is_match("bar99")
    re.close()


def test_from_import_class(rust_ns: None) -> None:
    mod = importlib.import_module("rust.regex")
    regex_cls = mod.Regex
    with regex_cls(r"\d+") as re:
        assert re.is_match("abc123")


def test_bad_pattern_raises_named_error(rust_ns: None) -> None:
    import rust.regex

    with pytest.raises(rust.regex.RegexError):
        rust.regex.Regex("(unclosed")


def test_rust_is_namespace_package(rust_ns: None) -> None:
    import rust

    assert rust.__name__ == "rust"


def test_missing_crate_is_import_error(rust_ns: None) -> None:
    with pytest.raises(ImportError):
        importlib.import_module("rust.no_such_crate_xyz")


def test_finalizer_drops_without_explicit_close(rust_ns: None) -> None:
    """D3: GC alone must drop the handle exactly once via weakref.finalize."""
    import rust.regex

    re = rust.regex.Regex("abc")
    fin = re._finalizer
    assert fin.alive
    del re
    gc.collect()
    assert not fin.alive  # finalizer ran exactly once at GC


def test_close_detaches_finalizer(rust_ns: None) -> None:
    """close() must drop and mark the finalizer dead so GC can't double-drop."""
    import rust.regex

    re = rust.regex.Regex("abc")
    fin = re._finalizer
    re.close()
    assert not fin.alive
    re.close()  # idempotent
    assert not fin.alive


def test_supported_abi_is_one() -> None:
    assert SUPPORTED_ABI == 1


def test_unsupported_abi_fails_closed(
    rust_ns: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    """D2: a bridge declaring a newer ABI must fail closed with a readable error,
    never a segfault or a misparse."""
    from jac_bridge_loader import rust_namespace

    real_parse = rust_namespace.parse

    def fake_parse(blob: bytes) -> BridgeMeta:
        meta = real_parse(blob)
        meta.abi_version = SUPPORTED_ABI + 1
        return meta

    monkeypatch.setattr(rust_namespace, "parse", fake_parse)
    with pytest.raises(ImportError, match="ABI version"):
        importlib.import_module("rust.regex")
