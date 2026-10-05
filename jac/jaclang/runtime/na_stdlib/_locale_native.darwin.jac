import from c { def setlocale(category: i32, locale: int) -> int;  }
import from c { def localeconv -> int;  }
import from c { def nl_langinfo(item: i32) -> int;  }
import from c { def strcoll(a: str, b: str) -> i32;  }
import from c { def strxfrm(dest: bytes, src: str, n: u64) -> u64;  }
import from c { def strdup(s: int) -> str;  }
import from c { def strstr(haystack: str, needle: str) -> int;  }

glob _LC_CTYPE: int = 2,
     _LC_NUMERIC: int = 4,
     _LC_TIME: int = 5,
     _LC_COLLATE: int = 1,
     _LC_MONETARY: int = 3,
     _LC_MESSAGES: int = 6,
     _LC_ALL: int = 0,
     _CODESET: int = 0;


def:pub loc_categories -> list[int] {
    out: list[int] = [];
    out.append(_LC_CTYPE);
    out.append(_LC_NUMERIC);
    out.append(_LC_TIME);
    out.append(_LC_COLLATE);
    out.append(_LC_MONETARY);
    out.append(_LC_MESSAGES);
    out.append(_LC_ALL);
    return out;
}


def:pub loc_query(category: int) -> str {
    p: int = setlocale(i32(category), 0);
    if p == 0 {
        return "";
    }
    return strdup(p);
}


def:pub loc_set(category: int, name: str) -> str {
    p: int = setlocale(i32(category), strstr(name, ""));
    if p == 0 {
        return "";
    }
    return strdup(p);
}


def:pub loc_conv_str(index: int) -> str {
    base: int = localeconv();
    if base == 0 {
        return "";
    }
    p: int = __mem_load_i64(base + index * 8);
    if p == 0 {
        return "";
    }
    return strdup(p);
}


def:pub loc_conv_char(index: int) -> int {
    base: int = localeconv();
    if base == 0 {
        return 127;
    }
    word: int = __mem_load_i64(base + 80 + (index // 8) * 8);
    return (word >> ((index % 8) * 8)) & 255;
}


def:pub loc_codeset -> str {
    p: int = nl_langinfo(i32(_CODESET));
    if p == 0 {
        return "";
    }
    return strdup(p);
}


def:pub loc_strcoll(a: str, b: str) -> int {
    return int(strcoll(a, b));
}


def:pub loc_strxfrm(src: str) -> str {
    probe: bytes = b"\x00";
    need: int = int(strxfrm(probe, src, u64(0)));
    buf: bytes = b"\x00" * (need + 1);
    strxfrm(buf, src, u64(need + 1));
    return buf[0:need].decode();
}
