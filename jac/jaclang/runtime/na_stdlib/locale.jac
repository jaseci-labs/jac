import from ._locale_native {
    loc_categories,
    loc_query,
    loc_set,
    loc_conv_str,
    loc_conv_char,
    loc_codeset,
    loc_strcoll,
    loc_strxfrm
}
import from ._locale_tables { _load_alias, _load_encalias }
import os;

glob:pub CHAR_MAX: int = 127;

glob:pub LC_CTYPE: int = loc_categories()[0],
     LC_NUMERIC: int = loc_categories()[1],
     LC_TIME: int = loc_categories()[2],
     LC_COLLATE: int = loc_categories()[3],
     LC_MONETARY: int = loc_categories()[4],
     LC_MESSAGES: int = loc_categories()[5],
     LC_ALL: int = loc_categories()[6];

glob:pub locale_alias: dict[str, str] = _load_alias(),
     locale_encoding_alias: dict[str, str] = _load_encalias();


obj:pub Error(Exception) {}


def:pub setlocale(category: int, locale: (str | None) = None) -> str {
    name: str | None = locale;
    if name is None {
        return loc_query(category);
    }
    want: str = name;
    out: str = loc_set(category, want);
    if out == "" {
        raise Error("unsupported locale setting");
    }
    return out;
}


def:pub getencoding -> str {
    enc: str = loc_codeset();
    if enc == "" {
        return "UTF-8";
    }
    return enc;
}


def:pub getpreferredencoding(do_setlocale: bool = True) -> str {
    if not do_setlocale {
        return getencoding();
    }
    old: str = loc_query(LC_CTYPE);
    loc_set(LC_CTYPE, "");
    enc: str = getencoding();
    if old != "" {
        loc_set(LC_CTYPE, old);
    }
    return enc;
}


def _cs(index: int) -> str {
    return loc_conv_str(index);
}


def _cc(index: int) -> int {
    return loc_conv_char(index);
}


def _cgroup(index: int) -> list[int] {
    out: list[int] = [];
    raw: str = loc_conv_str(index);
    i: int = 0;
    while i < len(raw) {
        out.append(ord(raw[i]));
        i += 1;
    }
    return out;
}


def:pub localeconv -> dict[str, any] {
    grouping: list[any] = [];
    for g in _cgroup(2) {
        grouping.append(g);
    }
    mon_grouping: list[any] = [];
    for g in _cgroup(7) {
        mon_grouping.append(g);
    }
    out: dict[str, any] = {};
    out["int_curr_symbol"] = loc_conv_str(3);
    out["currency_symbol"] = loc_conv_str(4);
    out["mon_decimal_point"] = loc_conv_str(5);
    out["mon_thousands_sep"] = loc_conv_str(6);
    out["mon_grouping"] = mon_grouping;
    out["positive_sign"] = loc_conv_str(8);
    out["negative_sign"] = loc_conv_str(9);
    out["int_frac_digits"] = loc_conv_char(0);
    out["frac_digits"] = loc_conv_char(1);
    out["p_cs_precedes"] = loc_conv_char(2);
    out["p_sep_by_space"] = loc_conv_char(3);
    out["n_cs_precedes"] = loc_conv_char(4);
    out["n_sep_by_space"] = loc_conv_char(5);
    out["p_sign_posn"] = loc_conv_char(6);
    out["n_sign_posn"] = loc_conv_char(7);
    out["decimal_point"] = loc_conv_str(0);
    out["thousands_sep"] = loc_conv_str(1);
    out["grouping"] = grouping;
    return out;
}


def:pub strcoll(a: str, b: str) -> int {
    return loc_strcoll(a, b);
}


def:pub strxfrm(s: str) -> str {
    return loc_strxfrm(s);
}


def _normalize_encoding(enc: str) -> str {
    out: str = "";
    n: int = len(enc);
    i: int = 0;
    punct: bool = False;
    while i < n {
        c: str = enc[i];
        alnum: bool = (c >= "a" and c <= "z")
            or (c >= "A" and c <= "Z")
            or (c >= "0" and c <= "9");
        if alnum {
            if punct and out != "" {
                out += "_";
            }
            out += c;
            punct = False;
        } else {
            punct = True;
        }
        i += 1;
    }
    return out;
}


def _replace_encoding(code: str, encoding: str) -> str {
    langname: str = code;
    dot: int = code.find(".");
    if dot >= 0 {
        langname = code[0:dot];
    }
    norm: str = _normalize_encoding(encoding);
    enc: str = norm;
    low: str = norm.lower();
    if low in locale_encoding_alias {
        enc = locale_encoding_alias[low];
    } else {
        low = "".join(low.split("_"));
        low = "".join(low.split("-"));
        if low in locale_encoding_alias {
            enc = locale_encoding_alias[low];
        }
    }
    return langname + "." + enc;
}


def _append_modifier(code: str, modifier: str) -> str {
    if modifier == "euro" {
        if "." not in code {
            return code + ".ISO8859-15";
        }
        dot: int = code.find(".");
        encoding: str = code[dot + 1:];
        if encoding == "ISO8859-15" or encoding == "UTF-8" {
            return code;
        }
        if encoding == "ISO8859-1" {
            return _replace_encoding(code, "ISO8859-15");
        }
    }
    return code + "@" + modifier;
}


def:pub normalize(localename: str) -> str {
    code: str = localename.lower();
    if ":" in code {
        code = ".".join(code.split(":"));
    }
    modifier: str = "";
    at: int = code.find("@");
    if at >= 0 {
        modifier = code[at + 1:];
        code = code[0:at];
    }
    langname: str = code;
    encoding: str = "";
    dot: int = code.find(".");
    if dot >= 0 {
        langname = code[0:dot];
        rest: str = code[dot + 1:];
        nd: int = rest.find(".");
        if nd >= 0 {
            encoding = rest[0:nd];
        } else {
            encoding = rest;
        }
    }
    lang_enc: str = langname;
    if encoding != "" {
        norm_encoding: str = "".join(encoding.split("-"));
        norm_encoding = "".join(norm_encoding.split("_"));
        lang_enc += "." + norm_encoding;
    }
    lookup_name: str = lang_enc;
    if modifier != "" {
        lookup_name += "@" + modifier;
    }
    if lookup_name in locale_alias {
        return locale_alias[lookup_name];
    }
    if modifier != "" and lang_enc in locale_alias {
        found: str = locale_alias[lang_enc];
        if "@" not in found {
            return _append_modifier(found, modifier);
        }
        fat: int = found.find("@");
        if found[fat + 1:].lower() == modifier {
            return found;
        }
    }
    if encoding != "" {
        lookup_name = langname;
        if modifier != "" {
            lookup_name += "@" + modifier;
        }
        if lookup_name in locale_alias {
            found = locale_alias[lookup_name];
            if "@" not in found {
                return _replace_encoding(found, encoding);
            }
            fat = found.find("@");
            return _replace_encoding(found[0:fat], encoding) + "@" + found[fat + 1:];
        }
        if modifier != "" and langname in locale_alias {
            found = locale_alias[langname];
            if "@" not in found {
                return _append_modifier(_replace_encoding(found, encoding), modifier);
            }
            fat = found.find("@");
            defmod: str = found[fat + 1:];
            if defmod.lower() == modifier {
                return _replace_encoding(found[0:fat], encoding) + "@" + defmod;
            }
        }
    }
    return localename;
}


def _parse_localename(localename: str) -> tuple[str | None, str | None] {
    code: str = normalize(localename);
    at: int = code.find("@");
    if at >= 0 {
        modifier: str = code[at + 1:];
        code = code[0:at];
        if modifier == "euro" and "." not in code {
            return (code, "iso-8859-15");
        }
    }
    dot: int = code.find(".");
    if dot >= 0 {
        rest: str = code[dot + 1:];
        nd: int = rest.find(".");
        if nd >= 0 {
            rest = rest[0:nd];
        }
        return (code[0:dot], rest);
    }
    if code == "C" {
        return (None, None);
    }
    if code == "UTF-8" {
        return (None, "UTF-8");
    }
    raise ValueError("unknown locale: " + localename);
}


def _build_localename(language: str = "", encoding: str = "") -> str {
    lang: str = language;
    if lang == "" {
        lang = "C";
    }
    if encoding == "" {
        return lang;
    }
    return lang + "." + encoding;
}


def:pub getlocale(category: int = -1) -> tuple[str | None, str | None] {
    cat: int = category;
    if cat < 0 {
        cat = LC_CTYPE;
    }
    localename: str = loc_query(cat);
    if cat == LC_ALL and ";" in localename {
        raise TypeError("category LC_ALL is not supported");
    }
    return _parse_localename(localename);
}


def:pub getdefaultlocale -> tuple[str | None, str | None] {
    keys: list[str] = ["LC_ALL", "LC_CTYPE", "LANG", "LANGUAGE"];
    localename: str = "C";
    for k in keys {
        val: str = os.getenv(k, "");
        if val != "" {
            if k == "LANGUAGE" {
                localename = val.split(":")[0];
            } else {
                localename = val;
            }
            break;
        }
    }
    return _parse_localename(localename);
}


def _grouping_intervals(grouping: list[int], width: int) -> list[int] {
    out: list[int] = [];
    last: int = -1;
    for interval in grouping {
        if interval == CHAR_MAX {
            return out;
        }
        if interval == 0 {
            if last < 0 {
                raise ValueError("invalid grouping");
            }
            k: int = 0;
            while k < width {
                out.append(last);
                k += 1;
            }
            return out;
        }
        out.append(interval);
        last = interval;
    }
    return out;
}


def _is_digit(c: str) -> bool {
    return c >= "0" and c <= "9";
}


def _group(s: str, monetary: bool = False) -> tuple[str, int] {
    sep_idx: int = 1;
    grp_idx: int = 2;
    if monetary {
        sep_idx = 6;
        grp_idx = 7;
    }
    thousands_sep: str = _cs(sep_idx);
    grouping: list[int] = _cgroup(grp_idx);
    if len(grouping) == 0 {
        return (s, 0);
    }
    body: str = s;
    right_spaces: str = "";
    if len(body) > 0 and body[len(body) - 1] == " " {
        stripped: str = body.rstrip();
        right_spaces = body[len(stripped):];
        body = stripped;
    }
    left_spaces: str = "";
    groups: list[str] = [];
    for interval in _grouping_intervals(grouping, len(body) + 1) {
        if len(body) == 0 or not _is_digit(body[len(body) - 1]) {
            left_spaces = body;
            body = "";
            break;
        }
        cut: int = len(body) - interval;
        if cut < 0 {
            cut = 0;
        }
        groups.append(body[cut:]);
        body = body[0:cut];
    }
    if body != "" {
        groups.append(body);
    }
    ordered: list[str] = [];
    i: int = len(groups) - 1;
    while i >= 0 {
        ordered.append(groups[i]);
        i -= 1;
    }
    return (
        left_spaces + thousands_sep.join(ordered) + right_spaces,
        len(thousands_sep) * (len(ordered) - 1)
    );
}


def _strip_padding(s: str, amount: int) -> str {
    left: int = 0;
    remaining: int = amount;
    while remaining > 0 and left < len(s) and s[left] == " " {
        left += 1;
        remaining -= 1;
    }
    right: int = len(s) - 1;
    while remaining > 0 and right >= 0 and s[right] == " " {
        right -= 1;
        remaining -= 1;
    }
    return s[left:right + 1];
}


def:pub localize(string: str, grouping: bool = False, monetary: bool = False) -> str {
    dp_idx: int = 0;
    if monetary {
        dp_idx = 5;
    }
    if "." in string {
        cut: int = string.find(".");
        head: str = string[0:cut];
        tail: str = string[cut + 1:];
        seps: int = 0;
        if grouping {
            grouped: tuple[str, int] = _group(head, monetary);
            head = grouped[0];
            seps = grouped[1];
        }
        out: str = head + _cs(dp_idx) + tail;
        if seps != 0 {
            out = _strip_padding(out, seps);
        }
        return out;
    }
    seps = 0;
    out = string;
    if grouping {
        grouped = _group(out, monetary);
        out = grouped[0];
        seps = grouped[1];
    }
    if seps != 0 {
        out = _strip_padding(out, seps);
    }
    return out;
}


def:pub delocalize(string: str) -> str {
    out: str = string;
    ts: str = _cs(1);
    if ts != "" {
        out = "".join(out.split(ts));
    }
    dd: str = _cs(0);
    if dd != "" and dd != "." {
        out = ".".join(out.split(dd));
    }
    return out;
}


def:pub atof(string: str) -> float {
    return float(delocalize(string));
}


def:pub atoi(string: str) -> int {
    return int(delocalize(string));
}


def:pub format_string(
    f: str, val: float, grouping: bool = False, monetary: bool = False
) -> str {
    n: int = len(f);
    out: str = "";
    i: int = 0;
    while i < n {
        c: str = f[i];
        if c != "%" {
            out += c;
            i += 1;
            continue;
        }
        if i + 1 < n and f[i + 1] == "%" {
            out += "%";
            i += 2;
            continue;
        }
        j: int = i + 1;
        spec: str = "";
        while j < n {
            ch: str = f[j];
            if ch == "e"
                or ch == "E"
                or ch == "f"
                or ch == "F"
                or ch == "g"
                or ch == "G"
                or ch == "d"
                or ch == "i"
                or ch == "u"
                or ch == "s" {
                break;
            }
            spec += ch;
            j += 1;
        }
        if j >= n {
            raise ValueError("incomplete format");
        }
        kind: str = f[j];
        rendered: str = "";
        if kind == "d" or kind == "i" or kind == "u" {
            rendered = format(int(val), spec + "d");
        } elif kind == "s" {
            rendered = str(val);
        } else {
            rendered = format(val, spec + kind);
        }
        if kind != "s" {
            rendered = localize(rendered, grouping, monetary);
        }
        out += rendered;
        i = j + 1;
    }
    return out;
}


def:pub currency(
    val: float, symbol: bool = True, grouping: bool = False, international: bool = False
) -> str {
    dig_idx: int = 1;
    if international {
        dig_idx = 0;
    }
    digits: int = _cc(dig_idx);
    if digits == 127 {
        raise ValueError("Currency formatting is not possible using the 'C' locale.");
    }
    mag: float = val;
    if mag < 0.0 {
        mag = -mag;
    }
    s: str = localize(format(mag, "." + str(digits) + "f"), grouping, True);
    s = "<" + s + ">";
    neg: bool = val < 0.0;
    if symbol {
        smb_idx: int = 4;
        if international {
            smb_idx = 3;
        }
        smb: str = _cs(smb_idx);
        pre_idx: int = 2;
        sep_idx: int = 3;
        if neg {
            pre_idx = 4;
            sep_idx = 5;
        }
        precedes: int = _cc(pre_idx);
        separated: int = _cc(sep_idx);
        gap: str = "";
        if separated != 0 {
            gap = " ";
        }
        if precedes != 0 {
            s = smb + gap + s;
        } else {
            if international and len(smb) > 0 and smb[len(smb) - 1] == " " {
                smb = smb[0:len(smb) - 1];
            }
            s = s + gap + smb;
        }
    }
    posn_idx: int = 6;
    sign_idx: int = 8;
    if neg {
        posn_idx = 7;
        sign_idx = 9;
    }
    sign_pos: int = _cc(posn_idx);
    sign: str = _cs(sign_idx);
    if sign_pos == 0 {
        s = "(" + s + ")";
    } elif sign_pos == 1 {
        s = sign + s;
    } elif sign_pos == 2 {
        s = s + sign;
    } elif sign_pos == 3 {
        s = sign.join(s.split("<"));
    } elif sign_pos == 4 {
        s = sign.join(s.split(">"));
    } else {
        s = sign + s;
    }
    s = "".join(s.split("<"));
    return "".join(s.split(">"));
}
