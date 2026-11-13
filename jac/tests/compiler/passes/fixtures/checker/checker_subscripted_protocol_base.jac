"""A class whose base is `Protocol[...]` is a protocol: a class with the members
conforms to it structurally. `AbstractContextManager[_T_co, _ExitT_co]` and
`os.PathLike[AnyStr_co]` are declared `(ABC, Protocol[...])` in typeshed.
Members are checked against the protocol's type arguments, and solving a
self-referential protocol (`Iterator.__iter__` returns `Iterator[_T_co]`)
terminates and still solves the next call. An overloaded member (`TextIO.write`)
is matched by the overload that fits the protocol's specialized signature."""

import contextlib;
import os;
import sys;
import from unittest.mock { patch }

obj Session {
    def __enter__ -> int {
        return 1;
    }

    def __exit__(kind: object, value: object, trace: object) -> None {
        return None;
    }
}

obj Location {
    def __fspath__ -> str {
        return "/tmp";
    }
}

obj NoExit {
    def __enter__ -> int {
        return 1;
    }
}

def manage(path: str) -> int {
    stack = contextlib.ExitStack();
    stack.enter_context(patch.object(os, "getcwd", return_value="/x"));
    stack.enter_context(open(path));
    entered: int = stack.enter_context(Session());
    where: os.PathLike[str] = Location();
    wrong: str = stack.enter_context(Session());
    stack.enter_context(NoExit());
    stack.close();
    return entered + len(os.fspath(where)) + len(wrong);
}

obj BytesLocation {
    def __fspath__ -> bytes {
        return b"/tmp";
    }
}

def copies(values: list[int]) -> int {
    first: list[int] = list(iter(values));
    second: list[str] = list(iter([str(v) for v in values]));
    wrong_path: os.PathLike[str] = BytesLocation();
    wrong_copy: list[str] = list(iter(values));
    print("copied", file=sys.stderr);
    return len(first) + len(second) + len(os.fspath(wrong_path)) + len(wrong_copy);
}
