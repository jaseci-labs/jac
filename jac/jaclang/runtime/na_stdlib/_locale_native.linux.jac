import from c { def setlocale(category: i32, locale: int) -> int;  }
import from c { def localeconv -> int;  }
import from c { def nl_langinfo(item: i32) -> int;  }
import from c { def strcoll(a: str, b: str) -> i32;  }
import from c { def strxfrm(dest: bytes, src: str, n: u64) -> u64;  }
import from c { def strdup(s: int) -> str;  }
import from c { def strstr(haystack: str, needle: str) -> int;  }

glob _LC_CTYPE: int = 0,
     _LC_NUMERIC: int = 1,
     _LC_TIME: int = 2,
     _LC_COLLATE: int = 3,
     _LC_MONETARY: int = 4,
     _LC_MESSAGES: int = 5,
     _LC_ALL: int = 6,
     _CODESET: int = 14;


def:pub loc_categories -> list[int];


def:pub loc_query(category: int) -> str;


def:pub loc_set(category: int, name: str) -> str;


def:pub loc_conv_str(index: int) -> str;


def:pub loc_conv_char(index: int) -> int;


def:pub loc_codeset -> str;


def:pub loc_strcoll(a: str, b: str) -> int;


def:pub loc_strxfrm(src: str) -> str;
