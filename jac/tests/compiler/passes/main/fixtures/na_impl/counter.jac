"""Native-arch declaration file (.jac).

Mirrors the real lexer.jac / parser pattern where the declaration
lives in a .jac file and implementation in impl/counter.impl.jac.
"""

obj Counter {
    has value: int = 0,
        step: int = 1;

    def increment -> None;
    def reset -> None;
    def current -> int;
}
