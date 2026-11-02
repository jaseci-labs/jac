"""@contextlib.contextmanager on functions and on a decl/impl method.

Each shape records what it saw in `EVENTS` and prints it, so the native
binary's output is diffed line-for-line against CPython's `contextlib`:
enter/exit around a plain body, a value bound by `as`, an exception from
the body running the generator's `finally` and propagating, an `except` in
the generator swallowing it (and not swallowing another type), early
`return`/`break`/`continue` out of the body, nesting (including a manager
that is itself a generator yielding inside a `with` of two others), and a
method whose declaration is in the decl file and body in the impl annex.
"""

import from contextlib { contextmanager }
import from contextmanager_lib { Tracker }

glob EVENTS: list[str] = [];

@contextmanager
def scope(name: str) -> Iterator[None] {
    EVENTS.append(f"open {name}");
    try {
        yield ;
    } finally {
        EVENTS.append(f"close {name}");
    }
}

@contextmanager
def value_of(n: int) -> Iterator[int] {
    EVENTS.append("value enter");
    yield n * 2;
    EVENTS.append("value exit");
}

@contextmanager
def swallow(kind: str) -> Iterator[None] {
    try {
        yield ;
    } except ValueError {
        EVENTS.append(f"swallowed in {kind}");
    }
}

@contextmanager
def outer_scope(name: str) -> Iterator[None] {
    with scope(name + ".a"), scope(name + ".b") {
        yield ;
    }
}

def flush(tag: str) {
    print(tag, EVENTS);
    EVENTS.clear();
}

def plain {
    with scope("plain") {
        EVENTS.append("body");
    }
    flush("plain");
}

def bound {
    with value_of(21) as v {
        EVENTS.append(f"v={v}");
    }
    flush("bound");
}

def raising {
    try {
        with scope("raising") {
            EVENTS.append("before");
            raise KeyError("boom");
        }
    } except KeyError {
        EVENTS.append("caught outside");
    }
    flush("raising");
}

def suppressed {
    with swallow("s") {
        EVENTS.append("in body");
        raise ValueError("bad");
    }
    EVENTS.append("after with");
    flush("suppressed");
}

def not_suppressed {
    try {
        with swallow("ns") {
            raise KeyError("other");
        }
    } except KeyError {
        EVENTS.append("propagated KeyError");
    }
    flush("not_suppressed");
}

def early(k: int) -> int {
    with scope("early") {
        if k > 0 {
            return k * 10;
        }
        EVENTS.append("fell through");
    }
    return -1;
}

def nested {
    with scope("n1") {
        with scope("n2") {
            EVENTS.append("inner");
        }
    }
    with outer_scope("gen") {
        EVENTS.append("in gen scope");
    }
    flush("nested");
}

def loops {
    for i in range(3) {
        with scope(f"loop{i}") {
            if i == 1 {
                continue;
            }
            if i == 2 {
                break;
            }
            EVENTS.append(f"iter{i}");
        }
    }
    flush("loops");
}

def method_cm {
    t = Tracker();
    with t.track("a") as d1 {
        with t.track("b") as d2 {
            t.log.append(f"depths {d1} {d2}");
        }
    }
    try {
        with t.track("c") {
            raise RuntimeError("inside");
        }
    } except RuntimeError {
        t.log.append("runtime caught");
    }
    print("method", t.log, t.depth);
}

with entry {
    plain();
    bound();
    raising();
    suppressed();
    not_suppressed();
    print("early", early(3));
    flush("early3");
    print("early", early(0));
    flush("early0");
    nested();
    loops();
    method_cm();
}
