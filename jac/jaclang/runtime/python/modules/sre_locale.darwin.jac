"""The locale-dependent character predicates of _sre (Modules/_sre/sre.c).

macOS classifies a locale's bytes through the wide character API: the byte
is widened with btowc() (USE_CTYPE_WINT_T), and a byte the locale does not
map (WEOF) is neither alphanumeric nor changed by case mapping but returns
WEOF. See ../LICENSE.cpython.
"""

import from c {
    def btowc(c: i32) -> i32;  def iswalnum(wc: i32) -> i32;  def towlower(
        wc: i32
    ) -> i32;  def towupper(wc: i32) -> i32;
}

# sre_isalnum(): nonzero when byte `ch` is alphanumeric in the current locale.
def sre_isalnum(ch: u32) -> bool {
    return iswalnum(btowc(i32(ch))) != 0;
}

# sre_tolower(): the current locale's lower case of byte `ch`.
def sre_tolower(ch: u32) -> u32 {
    return u32(i64(towlower(btowc(i32(ch)))) & 0xFFFFFFFF);
}

# sre_toupper(): the current locale's upper case of byte `ch`.
def sre_toupper(ch: u32) -> u32 {
    return u32(i64(towupper(btowc(i32(ch)))) & 0xFFFFFFFF);
}
