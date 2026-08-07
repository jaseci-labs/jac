"""A1 contract: Jac's ambient type vocabulary binds at runtime on every
bytecode tier, sourced from runtimelib/prelude.jac (not typing_ambient.pyi).

The jac0 bootstrap tier is the historically broken one: the checker called
these names ambient (W1103) while jac0-compiled modules NameErrored on any
value-position use without an explicit import."""

import os;
import tempfile;
import types as pytypes;

glob AMBIENT_PROBE_SRC = """
glob SEQ_OK = isinstance([1, 2], Sequence),
     MAP_OK = isinstance({'a': 1}, Mapping),
     ITER_OK = isinstance(iter([]), Iterator),
     CALL_OK = isinstance(len, Callable);

def probe_annotations(items: Sequence[int], table: Mapping[str, int]) -> int {
    return len(items) + len(table);
}

glob ANNOT_OK = probe_annotations([1, 2], {'a': 1}) == 3;
""";

def _exec_probe_via_bootstrap_tier -> pytypes.ModuleType {
    import from jaclang.meta_importer { JacMetaImporter }

    tmp = tempfile.mkdtemp(prefix="ambient_probe_");
    path = os.path.join(tmp, "ambient_probe.jac");
    with open(path, "w", encoding="utf-8") as f {
        f.write(AMBIENT_PROBE_SRC);
    }
    mod = pytypes.ModuleType("ambient_probe");
    mod.__file__ = path;
    JacMetaImporter()._exec_bootstrap(mod, path);
    return mod;
}

test "ambient vocabulary binds on the jac0 bootstrap tier" {
    mod = _exec_probe_via_bootstrap_tier();
    assert mod.SEQ_OK , "isinstance(list, Sequence) must hold ambiently";
    assert mod.MAP_OK , "isinstance(dict, Mapping) must hold ambiently";
    assert mod.ITER_OK , "isinstance(iter, Iterator) must hold ambiently";
    assert mod.CALL_OK , "isinstance(len, Callable) must hold ambiently";
    assert mod.ANNOT_OK , "annotation-position ambient names must not break";
}

test "explicit imports still win over ambient binding" {
    import from jaclang.meta_importer { JacMetaImporter }

    tmp = tempfile.mkdtemp(prefix="ambient_shadow_");
    path = os.path.join(tmp, "ambient_shadow.jac");
    with open(path, "w", encoding="utf-8") as f {
        f.write(
            """
import from collections.abc { Sequence }

glob STILL_OK = isinstance((1, 2), Sequence);
"""
        );
    }
    mod = pytypes.ModuleType("ambient_shadow");
    mod.__file__ = path;
    JacMetaImporter()._exec_bootstrap(mod, path);
    assert mod.STILL_OK;
}

test "prelude.jac is the single source of truth for the ambient set" {
    import collections.abc as abc_mod;
    import typing;
    import from jaclang.jac0core.ambient { ambient_imports_by_module, ambient_objects }

    groups = ambient_imports_by_module();
    assert set(groups.get("collections.abc", []))
        == {
            "AsyncIterable",
            "AsyncIterator",
            "Awaitable",
            "Callable",
            "Coroutine",
            "Iterable",
            "Iterator",
            "Mapping",
            "MutableMapping",
            "MutableSequence",
            "Sequence"
        } , "the 11 container/callable protocols come from collections.abc";
    assert set(groups.get("typing", [])) == {"Annotated", "ClassVar", "Literal"} , (
        "only the checker-erased annotation forms remain from typing"
    );

    objs = ambient_objects();
    assert objs["Sequence"] is abc_mod.Sequence;
    assert objs["Callable"] is abc_mod.Callable;
    assert objs["ClassVar"] is typing.ClassVar;
    assert "TypeVar" not in objs , "generics machinery is not ambient";
    assert "Protocol" not in objs , "generics machinery is not ambient";
    assert "Generic" not in objs , "generics machinery is not ambient";
}
