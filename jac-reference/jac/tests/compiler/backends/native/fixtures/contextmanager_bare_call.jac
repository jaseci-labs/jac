"""A @contextmanager function lowers natively as a generator driven by the
`with` that calls it; a call anywhere else needs the Python context-manager
object, so it is refused naming the function rather than lowered to a bare
iterator that nothing would ever enter or exit."""

import from contextlib { contextmanager }

@contextmanager
def scope(name: str) -> Iterator[None] {
    print("open", name);
    yield ;
    print("close", name);
}

def leak {
    cm = scope("bare");
    print(cm is not None);
}

with entry {
    leak();
}
