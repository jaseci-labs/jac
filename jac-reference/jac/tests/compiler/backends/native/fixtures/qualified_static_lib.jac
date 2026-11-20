"""Archetypes whose static methods a sibling calls through a module alias."""

obj Scale {
    has factor: int = 1;

    static def doubled(n: int) -> int {
        return n * 2;
    }

    static def offset(n: int, by_: int) -> int {
        return n + by_;
    }
}
