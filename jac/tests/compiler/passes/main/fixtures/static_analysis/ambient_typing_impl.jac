"""Ambient typing constructs (Callable, Sequence, ...) are valid in any scope,
including .impl.jac annex files. This fixture declares an archetype whose
signature references ambient typing names; the paired .impl.jac implements it
using the same names. The ambient names must not produce W2001, while a
genuinely undefined name referenced in the same annex still must."""

obj Runner {
    def run(cb: Callable[[], None]) -> Sequence[str];
    def broken -> None;
}
