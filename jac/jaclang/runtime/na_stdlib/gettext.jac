import os;
import from os.path { join, exists, abspath }
import from _file_native { read_file_bytes }
import from locale { normalize }

glob _OP_CONST: int = 0,
     _OP_N: int = 1,
     _OP_NOT: int = 2,
     _OP_OR: int = 3,
     _OP_AND: int = 4,
     _OP_EQ: int = 5,
     _OP_NE: int = 6,
     _OP_LT: int = 7,
     _OP_GT: int = 8,
     _OP_LE: int = 9,
     _OP_GE: int = 10,
     _OP_ADD: int = 11,
     _OP_SUB: int = 12,
     _OP_MUL: int = 13,
     _OP_DIV: int = 14,
     _OP_MOD: int = 15,
     _OP_IF: int = 16;


obj _PNode {
    has op: int,
        val: int = 0,
        a: _PNode | None = None,
        b: _PNode | None = None,
        c: _PNode | None = None;
}


obj _Toks {
    has items: list[str],
        i: int = 0;

    def peek -> str {
        if self.i >= len(self.items) {
            return "";
        }
        return self.items[self.i];
    }

    def next -> str {
        t: str = self.peek();
        self.i += 1;
        return t;
    }
}


def _is_digit(c: str) -> bool {
    return c >= "0" and c <= "9";
}


def _plural_tokens(src: str) -> list[str] {
    out: list[str] = [];
    n: int = len(src);
    i: int = 0;
    while i < n {
        c: str = src[i];
        if c == " " or c == "\t" {
            i += 1;
            continue;
        }
        if _is_digit(c) {
            j: int = i;
            while j < n and _is_digit(src[j]) {
                j += 1;
            }
            out.append(src[i:j]);
            i = j;
            continue;
        }
        if c == "n" {
            out.append("n");
            i += 1;
            continue;
        }
        if c == "("
            or c == ")"
            or c == "?"
            or c == ":"
            or c == "+"
            or c == "-"
            or c == "*"
            or c == "/"
            or c == "%" {
            out.append(c);
            i += 1;
            continue;
        }
        if c == "&" and i + 1 < n and src[i + 1] == "&" {
            out.append("&&");
            i += 2;
            continue;
        }
        if c == "|" and i + 1 < n and src[i + 1] == "|" {
            out.append("||");
            i += 2;
            continue;
        }
        if c == "<" or c == ">" or c == "!" or c == "=" {
            if i + 1 < n and src[i + 1] == "=" {
                out.append(c + "=");
                i += 2;
            } else {
                out.append(c);
                i += 1;
            }
            continue;
        }
        raise ValueError("invalid token in plural form: " + c);
    }
    return out;
}


def _binop_prio(tok: str) -> int {
    if tok == "||" {
        return 1;
    }
    if tok == "&&" {
        return 2;
    }
    if tok == "==" or tok == "!=" {
        return 3;
    }
    if tok == "<" or tok == ">" or tok == "<=" or tok == ">=" {
        return 4;
    }
    if tok == "+" or tok == "-" {
        return 5;
    }
    if tok == "*" or tok == "/" or tok == "%" {
        return 6;
    }
    return 0;
}


def _binop_code(tok: str) -> int {
    if tok == "||" {
        return _OP_OR;
    }
    if tok == "&&" {
        return _OP_AND;
    }
    if tok == "==" {
        return _OP_EQ;
    }
    if tok == "!=" {
        return _OP_NE;
    }
    if tok == "<" {
        return _OP_LT;
    }
    if tok == ">" {
        return _OP_GT;
    }
    if tok == "<=" {
        return _OP_LE;
    }
    if tok == ">=" {
        return _OP_GE;
    }
    if tok == "+" {
        return _OP_ADD;
    }
    if tok == "-" {
        return _OP_SUB;
    }
    if tok == "*" {
        return _OP_MUL;
    }
    if tok == "/" {
        return _OP_DIV;
    }
    return _OP_MOD;
}


def _perror(value: str) -> str {
    if value != "" {
        return "unexpected token in plural form: " + value;
    }
    return "unexpected end of plural form";
}


def _parse_plural(ts: _Toks, priority: int) -> _PNode {
    tok: str = ts.next();
    nots: int = 0;
    while tok == "!" {
        nots += 1;
        tok = ts.next();
    }
    left: _PNode = _PNode(op=_OP_CONST);
    if tok == "(" {
        left = _parse_plural(ts, -1);
        if ts.next() != ")" {
            raise ValueError("unbalanced parenthesis in plural form");
        }
    } elif tok == "n" {
        left = _PNode(op=_OP_N);
    } else {
        if tok == "" or not _is_digit(tok[0]) {
            raise ValueError(_perror(tok));
        }
        left = _PNode(op=_OP_CONST, val=int(tok));
    }
    while nots > 0 {
        left = _PNode(op=_OP_NOT, a=left);
        nots -= 1;
    }
    while True {
        nxt: str = ts.peek();
        prio: int = _binop_prio(nxt);
        if prio == 0 or prio < priority {
            break;
        }
        ts.next();
        right: _PNode = _parse_plural(ts, prio + 1);
        left = _PNode(op=_binop_code(nxt), a=left, b=right);
    }
    if ts.peek() == "?" and priority <= 0 {
        ts.next();
        if_true: _PNode = _parse_plural(ts, 0);
        if ts.next() != ":" {
            raise ValueError(_perror(ts.peek()));
        }
        if_false: _PNode = _parse_plural(ts, -1);
        left = _PNode(op=_OP_IF, a=left, b=if_true, c=if_false);
    }
    return left;
}


def _peval(nd: _PNode, n: int) -> int {
    op: int = nd.op;
    if op == _OP_CONST {
        return nd.val;
    }
    if op == _OP_N {
        return n;
    }
    an: _PNode | None = nd.a;
    av: int = 0;
    if an is not None {
        av = _peval(an, n);
    }
    if op == _OP_NOT {
        if av == 0 {
            return 1;
        }
        return 0;
    }
    if op == _OP_IF {
        bn: _PNode | None = nd.b;
        cn: _PNode | None = nd.c;
        if av != 0 {
            if bn is not None {
                return _peval(bn, n);
            }
            return 0;
        }
        if cn is not None {
            return _peval(cn, n);
        }
        return 0;
    }
    if op == _OP_OR {
        if av != 0 {
            return 1;
        }
        bn = nd.b;
        if bn is not None and _peval(bn, n) != 0 {
            return 1;
        }
        return 0;
    }
    if op == _OP_AND {
        if av == 0 {
            return 0;
        }
        bn = nd.b;
        if bn is not None and _peval(bn, n) != 0 {
            return 1;
        }
        return 0;
    }
    bn = nd.b;
    bv: int = 0;
    if bn is not None {
        bv = _peval(bn, n);
    }
    if op == _OP_EQ {
        return 1 if av == bv else 0;
    }
    if op == _OP_NE {
        return 1 if av != bv else 0;
    }
    if op == _OP_LT {
        return 1 if av < bv else 0;
    }
    if op == _OP_GT {
        return 1 if av > bv else 0;
    }
    if op == _OP_LE {
        return 1 if av <= bv else 0;
    }
    if op == _OP_GE {
        return 1 if av >= bv else 0;
    }
    if op == _OP_ADD {
        return av + bv;
    }
    if op == _OP_SUB {
        return av - bv;
    }
    if op == _OP_MUL {
        return av * bv;
    }
    if op == _OP_DIV {
        if bv == 0 {
            raise ZeroDivisionError("integer division or modulo by zero");
        }
        return av // bv;
    }
    if bv == 0 {
        raise ZeroDivisionError("integer division or modulo by zero");
    }
    return av % bv;
}


def:pub c2py_ast(plural: str) -> _PNode {
    if len(plural) > 1000 {
        raise ValueError("plural form expression is too long");
    }
    ts: _Toks = _Toks(items=_plural_tokens(plural));
    tree: _PNode = _parse_plural(ts, -1);
    if ts.peek() != "" {
        raise ValueError(_perror(ts.peek()));
    }
    return tree;
}


def:pub plural_index(tree: _PNode, n: int) -> int {
    return _peval(tree, n);
}


def:pub _expand_lang(loc: str) -> list[str] {
    base: str = normalize(loc);
    mask: int = 0;
    modifier: str = "";
    pos: int = base.find("@");
    if pos >= 0 {
        modifier = base[pos:];
        base = base[0:pos];
        mask = mask | 4;
    }
    codeset: str = "";
    pos = base.find(".");
    if pos >= 0 {
        codeset = base[pos:];
        base = base[0:pos];
        mask = mask | 1;
    }
    territory: str = "";
    pos = base.find("_");
    if pos >= 0 {
        territory = base[pos:];
        base = base[0:pos];
        mask = mask | 2;
    }
    language: str = base;
    ret: list[str] = [];
    i: int = 0;
    while i <= mask {
        if (i & (~mask)) == 0 {
            val: str = language;
            if (i & 2) != 0 {
                val += territory;
            }
            if (i & 1) != 0 {
                val += codeset;
            }
            if (i & 4) != 0 {
                val += modifier;
            }
            ret.append(val);
        }
        i += 1;
    }
    out: list[str] = [];
    k: int = len(ret) - 1;
    while k >= 0 {
        out.append(ret[k]);
        k -= 1;
    }
    return out;
}


obj:pub NullTranslations {
    has _info: dict[str, str],
        _charset: str,
        _fallback: NullTranslations | None;

    def init {
        self._info = {};
        self._charset = "";
        self._fallback = None;
    }

    def add_fallback(fallback: NullTranslations) {
        cur: NullTranslations | None = self._fallback;
        if cur is not None {
            cur.add_fallback(fallback);
        } else {
            self._fallback = fallback;
        }
    }

    def gettext(message: str) -> str {
        fb: NullTranslations | None = self._fallback;
        if fb is not None {
            return fb.gettext(message);
        }
        return message;
    }

    def ngettext(msgid1: str, msgid2: str, n: int) -> str {
        fb: NullTranslations | None = self._fallback;
        if fb is not None {
            return fb.ngettext(msgid1, msgid2, n);
        }
        if n == 1 {
            return msgid1;
        }
        return msgid2;
    }

    def pgettext(context: str, message: str) -> str {
        fb: NullTranslations | None = self._fallback;
        if fb is not None {
            return fb.pgettext(context, message);
        }
        return message;
    }

    def npgettext(context: str, msgid1: str, msgid2: str, n: int) -> str {
        fb: NullTranslations | None = self._fallback;
        if fb is not None {
            return fb.npgettext(context, msgid1, msgid2, n);
        }
        if n == 1 {
            return msgid1;
        }
        return msgid2;
    }

    def info -> dict[str, str] {
        return self._info;
    }

    def charset -> str {
        return self._charset;
    }
}


def _u32(buf: bytes, off: int, little: bool) -> int {
    if little {
        return buf[off]
            | (buf[off + 1] << 8)
            | (buf[off + 2] << 16)
            | (buf[off + 3] << 24);
    }
    return (buf[off] << 24) | (buf[off + 1] << 16) | (buf[off + 2] << 8) | buf[off + 3];
}


def _split_nul(data: bytes) -> list[bytes] {
    out: list[bytes] = [];
    n: int = len(data);
    start: int = 0;
    i: int = 0;
    while i < n {
        if data[i] == 0 {
            out.append(data[start:i]);
            start = i + 1;
        }
        i += 1;
    }
    out.append(data[start:n]);
    return out;
}


obj:pub GNUTranslations(NullTranslations) {
    has _catalog: dict[str, str],
        _plurals: dict[str, list[str]],
        _plural_ast: _PNode | None;

    def init(data: bytes = b"") {
        self._info = {};
        self._charset = "";
        self._fallback = None;
        self._catalog = {};
        self._plurals = {};
        self._plural_ast = None;
        if len(data) > 0 {
            self._parse_mo(data);
        }
    }

    def _plural(n: int) -> int {
        ast: _PNode | None = self._plural_ast;
        if ast is None {
            if n != 1 {
                return 1;
            }
            return 0;
        }
        return _peval(ast, n);
    }

    def _parse_mo(buf: bytes) {
        buflen: int = len(buf);
        if buflen < 20 {
            raise OSError("Bad magic number");
        }
        little: bool = True;
        magic: int = _u32(buf, 0, True);
        if magic == 2500072158 {
            little = True;
        } elif magic == 3725722773 {
            little = False;
        } else {
            raise OSError("Bad magic number");
        }
        version: int = _u32(buf, 4, little);
        major: int = version >> 16;
        if major != 0 and major != 1 {
            raise OSError("Bad version number " + str(major));
        }
        msgcount: int = _u32(buf, 8, little);
        masteridx: int = _u32(buf, 12, little);
        transidx: int = _u32(buf, 16, little);
        i: int = 0;
        while i < msgcount {
            mlen: int = _u32(buf, masteridx, little);
            moff: int = _u32(buf, masteridx + 4, little);
            tlen: int = _u32(buf, transidx, little);
            toff: int = _u32(buf, transidx + 4, little);
            mend: int = moff + mlen;
            tend: int = toff + tlen;
            if mend >= buflen or tend >= buflen {
                raise OSError("File is corrupt");
            }
            msg: bytes = buf[moff:mend];
            tmsg: bytes = buf[toff:tend];
            if mlen == 0 {
                self._read_headers(tmsg);
            }
            has_nul: bool = False;
            k: int = 0;
            while k < mlen {
                if msg[k] == 0 {
                    has_nul = True;
                }
                k += 1;
            }
            if has_nul {
                ids: list[bytes] = _split_nul(msg);
                strs: list[bytes] = _split_nul(tmsg);
                forms: list[str] = [];
                for sb in strs {
                    forms.append(sb.decode());
                }
                self._plurals[ids[0].decode()] = forms;
            } else {
                self._catalog[msg.decode()] = tmsg.decode();
            }
            masteridx += 8;
            transidx += 8;
            i += 1;
        }
    }

    def _read_headers(tmsg: bytes) {
        text: str = tmsg.decode();
        lastk: str = "";
        for raw in text.split("\n") {
            item: str = raw.strip();
            if item == "" {
                continue;
            }
            if item.startswith("#-#-#-#-#") and item.endswith("#-#-#-#-#") {
                continue;
            }
            cut: int = item.find(":");
            if cut >= 0 {
                key: str = item[0:cut].strip().lower();
                val: str = item[cut + 1:].strip();
                self._info[key] = val;
                lastk = key;
                if key == "content-type" {
                    marker: int = val.find("charset=");
                    if marker >= 0 {
                        self._charset = val[marker + 8:];
                    }
                } elif key == "plural-forms" {
                    parts: list[str] = val.split(";");
                    j: int = 0;
                    while j < len(parts) {
                        seg: str = parts[j];
                        at: int = seg.find("plural=");
                        if at >= 0 {
                            self._plural_ast = c2py_ast(seg[at + 7:]);
                        }
                        j += 1;
                    }
                }
            } elif lastk != "" {
                self._info[lastk] = self._info[lastk] + "\n" + item;
            }
        }
    }

    def gettext(message: str) -> str {
        if message in self._catalog {
            return self._catalog[message];
        }
        if message in self._plurals {
            forms: list[str] = self._plurals[message];
            idx: int = self._plural(1);
            if idx >= 0 and idx < len(forms) {
                return forms[idx];
            }
        }
        fb: NullTranslations | None = self._fallback;
        if fb is not None {
            return fb.gettext(message);
        }
        return message;
    }

    def ngettext(msgid1: str, msgid2: str, n: int) -> str {
        if msgid1 in self._plurals {
            forms: list[str] = self._plurals[msgid1];
            idx: int = self._plural(n);
            if idx >= 0 and idx < len(forms) {
                return forms[idx];
            }
        }
        fb: NullTranslations | None = self._fallback;
        if fb is not None {
            return fb.ngettext(msgid1, msgid2, n);
        }
        if n == 1 {
            return msgid1;
        }
        return msgid2;
    }

    def pgettext(context: str, message: str) -> str {
        key: str = context + "\x04" + message;
        if key in self._catalog {
            return self._catalog[key];
        }
        if key in self._plurals {
            forms: list[str] = self._plurals[key];
            idx: int = self._plural(1);
            if idx >= 0 and idx < len(forms) {
                return forms[idx];
            }
        }
        fb: NullTranslations | None = self._fallback;
        if fb is not None {
            return fb.pgettext(context, message);
        }
        return message;
    }

    def npgettext(context: str, msgid1: str, msgid2: str, n: int) -> str {
        key: str = context + "\x04" + msgid1;
        if key in self._plurals {
            forms: list[str] = self._plurals[key];
            idx: int = self._plural(n);
            if idx >= 0 and idx < len(forms) {
                return forms[idx];
            }
        }
        fb: NullTranslations | None = self._fallback;
        if fb is not None {
            return fb.npgettext(context, msgid1, msgid2, n);
        }
        if n == 1 {
            return msgid1;
        }
        return msgid2;
    }
}


glob:pub _default_localedir: str = "/usr/share/locale";


def _env_languages -> list[str] {
    keys: list[str] = ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"];
    for k in keys {
        val: str = os.getenv(k, "");
        if val != "" {
            return val.split(":");
        }
    }
    return [];
}


def _nelangs(languages: (list[str] | None)) -> list[str] {
    langs: list[str] = [];
    if languages is not None {
        langs = languages;
    } else {
        langs = _env_languages();
        if "C" not in langs {
            langs.append("C");
        }
    }
    out: list[str] = [];
    for lang in langs {
        for nelang in _expand_lang(lang) {
            if nelang not in out {
                out.append(nelang);
            }
        }
    }
    return out;
}


def:pub find_all(
    domain: str, localedir: str = "", languages: (list[str] | None) = None
) -> list[str] {
    base: str = localedir;
    if base == "" {
        base = _default_localedir;
    }
    out: list[str] = [];
    for lang in _nelangs(languages) {
        if lang == "C" {
            break;
        }
        mofile: str = join(base, lang, "LC_MESSAGES", domain + ".mo");
        if exists(mofile) {
            out.append(mofile);
        }
    }
    return out;
}


def:pub find(
    domain: str, localedir: str = "", languages: (list[str] | None) = None
) -> str | None {
    found: list[str] = find_all(domain, localedir, languages);
    if len(found) == 0 {
        return None;
    }
    return found[0];
}


def:pub translation(
    domain: str,
    localedir: str = "",
    languages: (list[str] | None) = None,
    fallback: bool = False
) -> NullTranslations {
    mofiles: list[str] = find_all(domain, localedir, languages);
    if len(mofiles) == 0 {
        if fallback {
            return NullTranslations();
        }
        raise FileNotFoundError("No translation file found for domain: " + domain);
    }
    result: NullTranslations = GNUTranslations(data=read_file_bytes(mofiles[0]));
    i: int = 1;
    while i < len(mofiles) {
        result.add_fallback(GNUTranslations(data=read_file_bytes(mofiles[i])));
        i += 1;
    }
    return result;
}


obj _Domain {
    has name: str,
        dirs: dict[str, str];

    def init {
        self.name = "messages";
        self.dirs = {};
    }
}

glob _CUR: _Domain = _Domain();


def:pub textdomain(domain: str = "") -> str {
    if domain != "" {
        _CUR.name = domain;
    }
    return _CUR.name;
}


def:pub bindtextdomain(domain: str, localedir: str = "") -> str {
    if localedir != "" {
        _CUR.dirs[domain] = localedir;
    }
    if domain in _CUR.dirs {
        return _CUR.dirs[domain];
    }
    return _default_localedir;
}


def _domain_dir(domain: str) -> str {
    if domain in _CUR.dirs {
        return _CUR.dirs[domain];
    }
    return "";
}


def:pub dgettext(domain: str, message: str) -> str {
    try {
        t: NullTranslations = translation(domain, _domain_dir(domain));
        return t.gettext(message);
    } except Exception {
        return message;
    }
}


def:pub dngettext(domain: str, msgid1: str, msgid2: str, n: int) -> str {
    try {
        t: NullTranslations = translation(domain, _domain_dir(domain));
        return t.ngettext(msgid1, msgid2, n);
    } except Exception {
        if n == 1 {
            return msgid1;
        }
        return msgid2;
    }
}


def:pub dpgettext(domain: str, context: str, message: str) -> str {
    try {
        t: NullTranslations = translation(domain, _domain_dir(domain));
        return t.pgettext(context, message);
    } except Exception {
        return message;
    }
}


def:pub dnpgettext(domain: str, context: str, msgid1: str, msgid2: str, n: int) -> str {
    try {
        t: NullTranslations = translation(domain, _domain_dir(domain));
        return t.npgettext(context, msgid1, msgid2, n);
    } except Exception {
        if n == 1 {
            return msgid1;
        }
        return msgid2;
    }
}


def:pub gettext(message: str) -> str {
    return dgettext(_CUR.name, message);
}


def:pub ngettext(msgid1: str, msgid2: str, n: int) -> str {
    return dngettext(_CUR.name, msgid1, msgid2, n);
}


def:pub pgettext(context: str, message: str) -> str {
    return dpgettext(_CUR.name, context, message);
}


def:pub npgettext(context: str, msgid1: str, msgid2: str, n: int) -> str {
    return dnpgettext(_CUR.name, context, msgid1, msgid2, n);
}
