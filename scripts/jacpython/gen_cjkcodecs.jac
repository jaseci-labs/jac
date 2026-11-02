"""Generate the mapping tables of the native CJK codec modules.

CPython's Tools/unicode/genmap_*.py write the tables Modules/cjkcodecs reads
as headers (mappings_cn.h, mappings_hk.h, mappings_jp.h, mappings_kr.h,
mappings_tw.h, mappings_jisx0213_pair.h). This script reads them, and the
MAPPING_* registries of the _codecs_<locale>.c files, from the pinned CPython
archive and writes them as C data definitions:

    jac run scripts/jacpython/gen_cjkcodecs.jac            # rewrite the tables
    jac run scripts/jacpython/gen_cjkcodecs.jac --check    # fail on drift

- jaclang/runtime/python/modules/cjkcodecs_mappings_<locale>.jac

A code array is a bytes literal of its little-endian elements. A 256-row
index (struct dbcs_index, unim_index, widedbcs_index) becomes a u32 array
whose entry packs (offset + 1) << 16 | bottom << 8 | top, 0 standing for a
row without a map, where offset is the row's start in the code array the
index points into. Each MAPPING_* entry becomes a DbcsMap record
(cjk_<charset>_map) and a module's list the array of their addresses, which
the module publishes as its `__map_<charset>` capsules.
"""
import argparse;
import re;
import sys;
import from pathlib { Path }
import from common {
    RUNTIME,
    archive_texts,
    bytes_literal,
    format_jac_many,
    pin,
    write_or_check
}

glob COMMAND: str = "scripts/jacpython/gen_cjkcodecs.jac",
     SOURCE: str = "Modules/cjkcodecs/",
     LOCALES: list[str] = ["cn", "hk", "jp", "kr", "tw"],
     # The code arrays' C types.
     CODE_TYPES: dict[str, str] = {
         "ucs2_t": "u16",
         "DBCHAR": "u16",
         "Py_UCS4": "u32",
         "unsigned char": "u8"
     },
     # cjkcodecs.h's short names of its special code points.
     MACROS: dict[str, int] = {"U": 0xFFFE, "N": 0xFFFF, "M": 0xFFFE, "D": 0xFFFD},
     INDEX_TYPES: list[str] = ["dbcs_index", "unim_index", "widedbcs_index"];

obj Unsupported(Exception) {}

def strip_comments(text: str) -> str {
    return re.sub(r"/\*.*?\*/", "", re.sub(r"//[^\n]*", "", text), flags=re.S);
}

# A header's text with the #ifdef EXTERN_JISX0213_PAIR branch removed: the
# port defines the pair tables where _codecs_jp.c does.
def defining_branch(text: str) -> str {
    m = re.search(r"#ifdef EXTERN_JISX0213_PAIR.*?#else\n(.*?)#endif", text, re.S);
    if m is None {
        return text;
    }
    return text[:m.start()] + m.group(1) + text[m.end():];
}

def value_of(item: str) -> int {
    item = item.strip();
    if item in MACROS {
        return MACROS[item];
    }
    return int(item, 0);
}

obj Header {
    has codes: dict[str, tuple[str, list[int]]] = {},
        indexes: dict[str, tuple[str, list[tuple[str, int, int, int]]]] = {},
        records: dict[str, list[list[int]]] = {},
        defines: dict[str, int] = {};

    def read(text: str) {
        text = strip_comments(defining_branch(text));
        for m in re.finditer(r"#define\s+(\w+)\s+(\d+)", text) {
            self.defines[m.group(1)] = int(m.group(2));
        }
        pattern = r"static const (unsigned char|ucs2_t|DBCHAR|Py_UCS4)\s+(\w+)\[\w*\]\s*=\s*\{(.*?)\};";
        for m in re.finditer(pattern, text, re.S) {
            values = [
                value_of(v)
                for v in m.group(3).split(",")
                if v.strip()
            ];
            self.codes[m.group(2)] = (CODE_TYPES[m.group(1)], values);
        }
        pattern = r"static const struct (\w+)\s+(\w+)\[\w*\]\s*=\s*\{(.*?)\n\};";
        for m in re.finditer(pattern, text, re.S) {
            kind = m.group(1);
            body = m.group(3);
            items = re.findall(r"\{([^{}]*)\}", body);
            if kind in INDEX_TYPES {
                rows: list[tuple[str, int, int, int]] = [];
                for item in items {
                    parts = [re.sub(r"\s+", "", p) for p in item.split(",")];
                    target = re.fullmatch(r"(\w+)\+(\d+)", parts[0]);
                    if target is not None {
                        rows.append(
                            (
                                target.group(1),
                                int(target.group(2)),
                                value_of(parts[1]),
                                value_of(parts[2])
                            )
                        );
                    } elif parts[0] == "0" {
                        rows.append(("", 0, 0, 0));
                    } else {
                        raise Unsupported(f"index row {item!r} of {m.group(2)}");
                    }
                }
                if len(rows) != 256 {
                    raise Unsupported(f"{m.group(2)} has {len(rows)} rows, not 256");
                }
                self.indexes[m.group(2)] = (kind, rows);
            } else {
                self.records[m.group(2)] = [
                    [value_of(p) for p in item.split(",")] for item in items
                ];
            }
        }
        # struct _gb18030_to_unibmp_ranges { ... } gb18030_to_unibmp_ranges[] = {...};
        m = re.search(
            r"struct _gb18030_to_unibmp_ranges\s*\{.*?\}\s*(\w+)\[\]\s*=\s*\{(.*?)\};",
            text,
            re.S
        );
        if m is not None {
            self.records[m.group(1)] = [
                [value_of(p) for p in item.split(",")]
                for item in re.findall(r"\{([^{}]*)\}", m.group(2))
            ];
        }
    }
}

# (charset, has encode map, has decode map) of a module's MAPPING_* list.
def mapping_list(source: str) -> list[tuple[str, bool, bool]] {
    found: list[tuple[str, bool, bool]] = [];
    for m in re.finditer(
        r"^\s*MAPPING_(ENCONLY|DECONLY|ENCDEC)\((\w+)\)", source, re.M
    ) {
        found.append((m.group(2), m.group(1) != "DECONLY", m.group(1) != "ENCONLY"));
    }
    return found;
}

obj Emitter {
    has constants: list[str] = [],
        data: list[str] = [],
        emitted: set[str] = set();

    def codes(header: Header, name: str) {
        if name in self.emitted {
            return;
        }
        self.emitted.add(name);
        (jt, values) = header.codes[name];
        self.data.append(
            f"cjk_{name.lstrip('_')}_codes: list[{jt}] = {bytes_literal(values, jt)}"
        );
    }

    # A 256-row index as packed u32 entries over the one code array it maps.
    def index(header: Header, name: str) -> str {
        (_, rows) = header.indexes[name];
        targets = {
            target
            for (target, _, _, _) in rows
            if target
        };
        if len(targets) != 1 {
            raise Unsupported(f"{name} indexes {sorted(targets)}");
        }
        target = targets.pop();
        self.codes(header, target);
        packed: list[int] = [];
        for (row_target, offset, bottom, top) in rows {
            if not row_target {
                packed.append(0);
                continue;
            }
            if offset + 1 >= 1 << 16 or not (0 <= bottom <= top <= 255) {
                raise Unsupported(
                    f"{name} row ({offset}, {bottom}, {top}) does not pack"
                );
            }
            packed.append((offset + 1) << 16 | bottom << 8 | top);
        }
        self.data.append(f"cjk_{name}: list[u32] = {bytes_literal(packed, 'u32')}");
        return target;
    }

    def records(name: str, struct: str, rows: list[list[int]]) {
        values = [f"{struct}({', '.join(str(v) for v in row)})" for row in rows];
        self.data.append(f"cjk_{name}: list[{struct}] = [{', '.join(values)}]");
    }

    def render(doc: list[str], imports: list[str]) -> str {
        out = ['"""' + doc[0]] + doc[1:] + ['"""'];
        out.append(
            f"import from jaclang.runtime.python.modules.cjkcodecs {{ {', '.join(
                sorted(imports)
            )} }}"
        );
        out.append("");
        if self.constants {
            out.append("glob " + ",\n     ".join(self.constants) + ";");
            out.append("");
        }
        out.append("import from c {");
        out.append("    glob " + ",\n         ".join(self.data) + ";");
        out.append("}");
        return "\n".join(out) + "\n";
    }
}

def locale_tables(locale: str, texts: dict[str, str], version: str) -> str {
    header = Header();
    headers = [f"mappings_{locale}.h"];
    if locale == "jp" {
        headers.append("mappings_jisx0213_pair.h");
    }
    for name in headers {
        header.read(texts[SOURCE + name]);
    }
    emitter = Emitter();
    imports = {"DbcsMap"};
    maps: list[str] = [];
    for (charset, enc, dec) in mapping_list(texts[SOURCE + f"_codecs_{locale}.c"]) {
        fields = [f"charset=ptr[u8](\"{charset}\")"];
        if enc {
            name = f"{charset}_encmap";
            if name in header.indexes {
                target = emitter.index(header, name);
                fields.append(f"encindex=addressof(cjk_{name})");
                fields.append(f"encdata=addressof(cjk_{target.lstrip('_')}_codes)");
            } elif name in header.records {
                # jisx0213_pair_encmap: the sorted pairs find_pairencmap searches.
                emitter.records(name, "PairEncodeMap", header.records[name]);
                imports.add("PairEncodeMap");
                fields.append(f"encdata=addressof(cjk_{name})");
            } else {
                raise Unsupported(f"no encode map {name}");
            }
        }
        if dec {
            name = f"{charset}_decmap";
            target = emitter.index(header, name);
            fields.append(f"decindex=addressof(cjk_{name})");
            fields.append(f"decdata=addressof(cjk_{target.lstrip('_')}_codes)");
        }
        emitter.data.append(
            f"cjk_{charset}_map: DbcsMap = DbcsMap({', '.join(fields)})"
        );
        maps.append(f"addressof(cjk_{charset}_map)");
    }
    for (name, (jt, values)) in header.codes.items() {
        # Code arrays no index points into: big5hkscs's pair hint bitmaps.
        if not name.startswith("__") {
            emitter.data.append(
                f"cjk_{name}: list[{jt}] = {bytes_literal(values, jt)}"
            );
        }
    }
    if "gb18030_to_unibmp_ranges" in header.records {
        emitter.records(
            "gb18030_to_unibmp_ranges",
            "Gb18030Range",
            header.records["gb18030_to_unibmp_ranges"]
        );
        imports.add("Gb18030Range");
    }
    for (name, value) in header.defines.items() {
        emitter.constants.append(f"{name}: Final[i64] = {value}");
    }
    emitter.constants.append(
        f"CJK_{locale.upper()}_MAPPINGS: Final[i64] = {len(maps)}"
    );
    emitter.data.append(
        f"cjk_{locale}_mappings: list[ptr[DbcsMap]] = [{', '.join(maps)}]"
    );
    return emitter.render(
        [
            f"The mapping tables of the native _codecs_{locale} module.",
            "",
            f"Generated by {COMMAND} from CPython {version}",
            f"Modules/cjkcodecs/{', '.join(headers)}",
            f"(Tools/unicode/genmap_*.py) and the MAPPING_* list of _codecs_{locale}.c;",
            "do not edit. Code arrays are bytes literals of their little-endian",
            "elements; an index entry packs (offset + 1) << 16 | bottom << 8 | top.",
            "See ../LICENSE.cpython."
        ],
        list(imports)
    );
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate the native CJK codec modules' mapping tables"
    );
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    texts = archive_texts((SOURCE, ));
    version = pin()["version"];
    rendered: list[tuple[str, Path]] = [];
    try {
        for locale in LOCALES {
            rendered.append(
                (
                    locale_tables(locale, texts, version),
                    RUNTIME / f"modules/cjkcodecs_mappings_{locale}.jac"
                )
            );
        }
    } except Unsupported as reason {
        sys.exit(f"{COMMAND}: {reason}");
    }
    formatted = format_jac_many(rendered);
    current = True;
    for ((_, target), text) in zip(rendered, formatted) {
        current = write_or_check(target, text, args.check, COMMAND) and current;
    }
    if not current {
        sys.exit(1);
    }
}
