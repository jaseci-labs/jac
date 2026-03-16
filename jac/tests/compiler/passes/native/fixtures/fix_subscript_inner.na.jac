"""Inner struct for cross-module list-subscript multilevel field access test (FIX 5).

Uses only int fields so results can be returned through ctypes without
any string handling.
"""

obj:pub Inner {
    has count: int;
    has extra: int;
}
