"""Impl annex: a `glob` and an `enum` declared HERE must resolve on native."""
glob SZ: int = 42;

enum Color { RED = 7, GREEN = 9 }

impl read_sz() -> int { return SZ; }
impl floordiv_sz(k: int) -> int { return k // SZ; }
impl enum_annex() -> int { return Color.GREEN.value; }
