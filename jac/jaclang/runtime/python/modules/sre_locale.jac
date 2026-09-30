"""The locale-dependent character predicates of _sre (Modules/_sre/sre.c).

Outside macOS the locale's byte classification is the C library's isalnum(),
tolower() and toupper(). See ../LICENSE.cpython.
"""

import from c {
    def isalnum(c: i32) -> i32;  def tolower(c: i32) -> i32;  def toupper(
        c: i32
    ) -> i32;
}

# sre_isalnum(): nonzero when byte `ch` is alphanumeric in the current locale.
def sre_isalnum(ch: u32) -> bool {
    return isalnum(i32(ch)) != 0;
}

# sre_tolower(): the current locale's lower case of byte `ch`.
def sre_tolower(ch: u32) -> u32 {
    return u32(i64(tolower(i32(ch))) & 0xFFFFFFFF);
}

# sre_toupper(): the current locale's upper case of byte `ch`.
def sre_toupper(ch: u32) -> u32 {
    return u32(i64(toupper(i32(ch))) & 0xFFFFFFFF);
}
