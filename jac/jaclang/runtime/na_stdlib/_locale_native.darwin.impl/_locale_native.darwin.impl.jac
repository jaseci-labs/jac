impl loc_categories -> list[int] {
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


impl loc_query(category: int) -> str {
    p: int = setlocale(i32(category), 0);
    if p == 0 {
        return "";
    }
    return strdup(p);
}


impl loc_set(category: int, name: str) -> str {
    p: int = setlocale(i32(category), strstr(name, ""));
    if p == 0 {
        return "";
    }
    return strdup(p);
}


impl loc_conv_str(index: int) -> str {
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


impl loc_conv_char(index: int) -> int {
    base: int = localeconv();
    if base == 0 {
        return 127;
    }
    word: int = __mem_load_i64(base + 80 + (index // 8) * 8);
    return (word >> ((index % 8) * 8)) & 255;
}


impl loc_codeset -> str {
    p: int = nl_langinfo(i32(_CODESET));
    if p == 0 {
        return "";
    }
    return strdup(p);
}


impl loc_strcoll(a: str, b: str) -> int {
    return int(strcoll(a, b));
}


impl loc_strxfrm(src: str) -> str {
    probe: bytes = b"\x00";
    need: int = int(strxfrm(probe, src, u64(0)));
    buf: bytes = b"\x00" * (need + 1);
    strxfrm(buf, src, u64(need + 1));
    return buf[0:need].decode();
}
