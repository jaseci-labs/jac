"""Ambient typing constructs (Callable, Sequence, ...) are valid in any scope,
including .impl.jac annex files. This fixture declares an archetype whose
signature references ambient typing names; the paired .impl.jac implements it
using the same names. Neither file may produce W2001 ('may be undefined')."""

obj Runner {
    def run(cb: Callable[[], None]) -> Sequence[str];
}
