import from os.path { splitext, isfile }
import from _file_native { read_file_bytes }
import from _mimetypes_tables {
    _default_knownfiles,
    _default_suffix_map,
    _default_encodings_map,
    _default_types_ext,
    _default_types_val,
    _default_common_ext,
    _default_common_val
}


def _split_words(line: str) -> list[str] {
    out: list[str] = [];
    cur: str = "";
    n: int = len(line);
    i: int = 0;
    while i < n {
        c: str = line[i];
        if c == " "
            or c == "\t"
            or c == "\n"
            or c == "\r"
            or c == "\x0b"
            or c == "\x0c" {
            if cur != "" {
                out.append(cur);
                cur = "";
            }
        } else {
            cur += c;
        }
        i += 1;
    }
    if cur != "" {
        out.append(cur);
    }
    return out;
}


def _scheme_of(url: str) -> str {
    n: int = len(url);
    i: int = 0;
    while i < n {
        c: str = url[i];
        if c == ":" {
            if i == 0 {
                return "";
            }
            return url[0:i].lower();
        }
        ok: bool = (c >= "a" and c <= "z")
            or (c >= "A" and c <= "Z")
            or (c >= "0" and c <= "9")
            or c == "+"
            or c == "-"
            or c == ".";
        if not ok {
            return "";
        }
        if i == 0 and not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z")) {
            return "";
        }
        i += 1;
    }
    return "";
}


obj:pub MimeTypes {
    has encodings_map: dict[str, str],
        suffix_map: dict[str, str],
        _strict_map: dict[str, str],
        _lax_map: dict[str, str],
        _strict_inv: dict[str, list[str]],
        _lax_inv: dict[str, list[str]];

    def init(filenames: (list[str] | None) = None, strict: bool = True) {
        self.encodings_map = _default_encodings_map();
        self.suffix_map = _default_suffix_map();
        self._strict_map = {};
        self._lax_map = {};
        self._strict_inv = {};
        self._lax_inv = {};
        exts: list[str] = _default_types_ext();
        vals: list[str] = _default_types_val();
        i: int = 0;
        while i < len(exts) {
            self.add_type(vals[i], exts[i], True);
            i += 1;
        }
        cexts: list[str] = _default_common_ext();
        cvals: list[str] = _default_common_val();
        i = 0;
        while i < len(cexts) {
            self.add_type(cvals[i], cexts[i], False);
            i += 1;
        }
        names: list[str] = [];
        if filenames is not None {
            names = filenames;
        }
        for nm in names {
            self.read(nm, strict);
        }
    }

    def add_type(type: str, ext: str, strict: bool = True) -> None {
        if type == "" {
            return;
        }
        if strict {
            self._strict_map[ext] = type;
            if type in self._strict_inv {
                cur: list[str] = self._strict_inv[type];
                if ext not in cur {
                    cur.append(ext);
                }
            } else {
                fresh: list[str] = [];
                fresh.append(ext);
                self._strict_inv[type] = fresh;
            }
        } else {
            self._lax_map[ext] = type;
            if type in self._lax_inv {
                cur = self._lax_inv[type];
                if ext not in cur {
                    cur.append(ext);
                }
            } else {
                fresh = [];
                fresh.append(ext);
                self._lax_inv[type] = fresh;
            }
        }
    }

    def _guess(path: str, strict: bool) -> tuple[str | None, str | None] {
        parts: tuple[(str, str)] = splitext(path);
        base: str = parts[0];
        ext: str = parts[1];
        low: str = ext.lower();
        while low in self.suffix_map {
            parts = splitext(base + self.suffix_map[low]);
            base = parts[0];
            ext = parts[1];
            low = ext.lower();
        }
        encoding: str | None = None;
        if ext in self.encodings_map {
            encoding = self.encodings_map[ext];
            parts = splitext(base);
            base = parts[0];
            ext = parts[1];
        }
        ext = ext.lower();
        if ext in self._strict_map {
            return (self._strict_map[ext], encoding);
        }
        if strict {
            return (None, encoding);
        }
        if ext in self._lax_map {
            return (self._lax_map[ext], encoding);
        }
        return (None, encoding);
    }

    def guess_file_type(
        path: str, strict: bool = True
    ) -> tuple[str | None, str | None] {
        return self._guess(path, strict);
    }

    def guess_type(url: str, strict: bool = True) -> tuple[str | None, str | None] {
        scheme: str = _scheme_of(url);
        if scheme == "" or len(scheme) <= 1 {
            return self._guess(url, strict);
        }
        rest: str = url[len(scheme) + 1:];
        if scheme == "data" {
            comma: int = rest.find(",");
            if comma < 0 {
                return (None, None);
            }
            semi: int = rest[0:comma].find(";");
            mtype: str = "";
            if semi >= 0 {
                mtype = rest[0:semi];
            } else {
                mtype = rest[0:comma];
            }
            if "=" in mtype or "/" not in mtype {
                mtype = "text/plain";
            }
            return (mtype, None);
        }
        return self._guess(rest, strict);
    }

    def guess_all_extensions(type: str, strict: bool = True) -> list[str] {
        key: str = type.lower();
        out: list[str] = [];
        if key in self._strict_inv {
            for e in self._strict_inv[key] {
                out.append(e);
            }
        }
        if not strict and key in self._lax_inv {
            for e in self._lax_inv[key] {
                if e not in out {
                    out.append(e);
                }
            }
        }
        return out;
    }

    def guess_extension(type: str, strict: bool = True) -> str | None {
        exts: list[str] = self.guess_all_extensions(type, strict);
        if len(exts) == 0 {
            return None;
        }
        return exts[0];
    }

    def read(filename: str, strict: bool = True) {
        raw: bytes = read_file_bytes(filename);
        text: str = raw.decode();
        for line in text.split("\n") {
            words: list[str] = _split_words(line);
            kept: list[str] = [];
            for w in words {
                if w[0] == "#" {
                    break;
                }
                kept.append(w);
            }
            if len(kept) < 2 {
                continue;
            }
            mtype: str = kept[0];
            i: int = 1;
            while i < len(kept) {
                self.add_type(mtype, "." + kept[i], strict);
                i += 1;
            }
        }
    }

    def strict_map -> dict[str, str] {
        return self._strict_map;
    }

    def lax_map -> dict[str, str] {
        return self._lax_map;
    }
}


def _boot -> MimeTypes {
    fresh: MimeTypes = MimeTypes();
    for nm in _default_knownfiles() {
        if isfile(nm) {
            fresh.read(nm, True);
        }
    }
    return fresh;
}


glob _DB: MimeTypes = _boot();

glob:pub inited: bool = True;

glob:pub suffix_map: dict[str, str] = _DB.suffix_map,
     encodings_map: dict[str, str] = _DB.encodings_map,
     types_map: dict[str, str] = _DB.strict_map(),
     common_types: dict[str, str] = _DB.lax_map();


def:pub init(files: (list[str] | None) = None) {
    names: list[str] = _default_knownfiles();
    if files is not None {
        for f in files {
            names.append(f);
        }
    }
    for nm in names {
        if isfile(nm) {
            _DB.read(nm, True);
        }
    }
}


def:pub guess_type(url: str, strict: bool = True) -> tuple[str | None, str | None] {
    return _DB.guess_type(url, strict);
}


def:pub guess_file_type(
    path: str, strict: bool = True
) -> tuple[str | None, str | None] {
    return _DB.guess_file_type(path, strict);
}


def:pub guess_all_extensions(type: str, strict: bool = True) -> list[str] {
    return _DB.guess_all_extensions(type, strict);
}


def:pub guess_extension(type: str, strict: bool = True) -> str | None {
    return _DB.guess_extension(type, strict);
}


def:pub add_type(type: str, ext: str, strict: bool = True) {
    _DB.add_type(type, ext, strict);
}


def:pub read_mime_types(file: str) -> dict[str, str] | None {
    if not isfile(file) {
        return None;
    }
    fresh: MimeTypes = MimeTypes();
    fresh.read(file, True);
    return fresh.strict_map();
}
