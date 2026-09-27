"""A decl-file method decorated with `@contextmanager` whose body lives in
the impl annex, the shape the compiler's `CompileProgress.track` uses."""

import from contextlib { contextmanager }

obj Tracker {
    has depth: int = 0,
        log: list[str] = [];

    @contextmanager
    def track(label: str) -> Iterator[int];
}
