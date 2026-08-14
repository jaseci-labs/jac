import jaclang.jac0core.parser.lexer as ct_lexer;

import from jaclang.jac0core.parser.parser { Parser }
import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    Enum,
    Module,
    Name,
    ParamVar
}


obj CtFieldInfo {
    has name: str,
        ann: str = "",
        default_src: str = "",
        has_default: bool = False,
        is_postinit: bool = False,
        is_static: bool = False,
        has_accessors: bool = False;
}


obj CtTypeInfo {
    has name: str,
        bases: list[str] = [],
        fields: list[CtFieldInfo] = [],
        init_params: list[CtFieldInfo] = [],
        has_explicit_init: bool = False,
        is_enum: bool = False,
        members: list[str] = [];
}


obj CtModuleInfo {
    has path: str,
        types: dict[str, CtTypeInfo] = {},
        order: list[str] = [];

    def type_names -> list[str] {
        return list(self.order);
    }

    def get(name: str) -> (CtTypeInfo | None) {
        return self.types.get(name);
    }

    def enum_members(name: str) -> list[str] {
        ti = self.types.get(name);
        return list(ti.members) if ti is not None else [];
    }

    def linearize(name: str) -> list[str] {
        return _c3(self, name);
    }

    def is_subtype(name: str, base: str) -> bool {
        return base in _c3(self, name);
    }

    def subtypes_of(base: str) -> list[str] {
        out: list[str] = [];
        for nm in self.order {
            ti = self.types[nm];
            if not ti.is_enum and nm != base and self.is_subtype(nm, base) {
                out.append(nm);
            }
        }
        return out;
    }

    def ctor_fields(name: str) -> list[CtFieldInfo] {
        mro = _c3(self, name);
        for cls in mro {
            ti0 = self.types.get(cls);
            if ti0 is not None and ti0.has_explicit_init {
                return list(ti0.init_params);
            }
        }
        ordered: list[str] = [];
        merged: dict[str, CtFieldInfo] = {};
        for cls in reversed(mro) {
            ti = self.types.get(cls);
            if ti is None {
                continue;
            }
            for f in ti.fields {
                if f.name not in merged {
                    ordered.append(f.name);
                }
                merged[f.name] = f;
            }
        }
        out: list[CtFieldInfo] = [];
        for fname in ordered {
            f = merged[fname];
            if f.is_postinit or f.has_accessors {
                continue;
            }
            out.append(f);
        }
        return out;
    }
}


glob _MODULE_CACHE: dict[str, CtModuleInfo] = {};


def _module_path(dotted: str, cur_dir: str) -> str {
    import os;
    if dotted.startswith("jaclang.") or dotted == "jaclang" {
        import jaclang;
        pkg_root = os.path.dirname(jaclang.__file__);
        rel = dotted[len("jaclang."):].replace(".", os.sep) + ".jac";
        return os.path.join(pkg_root, rel);
    }
    return os.path.join(cur_dir, dotted.replace(".", os.sep) + ".jac");
}


def _clean_src(nd: any) -> str {
    import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
    txt = " ".join(unparse_node(nd).split());
    for pair in (
        (" [", "["),
        ("[ ", "["),
        (" ]", "]"),
        (" (", "("),
        ("( ", "("),
        (" )", ")"),
        (" .", "."),
        (". ", "."),
        (" ,", ","),
        (", ", ",")
    ) {
        while pair[0] in txt {
            txt = txt.replace(pair[0], pair[1]);
        }
    }
    return txt;
}


def _field_infos(stmt: ArchHas) -> list[CtFieldInfo] {
    out: list[CtFieldInfo] = [];
    for hv in stmt.vars {
        ann = "";
        if hv.type_tag is not None and hv.type_tag.tag is not None {
            ann = _clean_src(hv.type_tag.tag);
        }
        dflt = "";
        has_d = hv.value is not None;
        if has_d {
            dflt = _clean_src(hv.value);
        }
        out.append(
            CtFieldInfo(
                name=hv.name.value,
                ann=ann,
                default_src=dflt,
                has_default=has_d,
                is_postinit=hv.defer,
                is_static=stmt.is_static,
                has_accessors=(hv.accessors is not None and len(list(hv.accessors)) > 0)
            )
        );
    }
    return out;
}


def _init_param_infos(abil: Ability) -> list[CtFieldInfo] {
    out: list[CtFieldInfo] = [];
    sig = abil.signature;
    params: list[any] = list(sig?.params or []);
    for pv in params {
        if not isinstance(pv, ParamVar) {
            continue;
        }
        ann = "";
        if pv.type_tag is not None and pv.type_tag.tag is not None {
            ann = _clean_src(pv.type_tag.tag);
        }
        has_d = pv.value is not None;
        dflt = _clean_src(pv.value) if has_d else "";
        out.append(
            CtFieldInfo(
                name=pv.name.value,
                ann=ann,
                default_src=dflt,
                has_default=has_d,
                is_postinit=False,
                is_static=False,
                has_accessors=False
            )
        );
    }
    return out;
}


def _base_names(arch: any) -> list[str] {
    out: list[str] = [];
    if arch.base_classes is None {
        return out;
    }
    for b in arch.base_classes {
        if isinstance(b, Name) {
            out.append(b.value);
        } else {
            out.append(_clean_src(b).replace(" ", ""));
        }
    }
    return out;
}


def _enum_member_names(en: Enum) -> list[str] {
    out: list[str] = [];
    body = en.body if en.body is not None else [];
    for item in body {
        if isinstance(item, Assignment) {
            for tgt in item.target {
                if isinstance(tgt, Name) {
                    out.append(tgt.value);
                }
            }
        } elif isinstance(item, Name) {
            out.append(item.value);
        }
    }
    return out;
}


def load_module(dotted: str, cur_dir: str = "") -> CtModuleInfo {
    key = _module_path(dotted, cur_dir);
    got = _MODULE_CACHE.get(key);
    if got is not None {
        return got;
    }
    src_txt = open(key, encoding="utf-8").read();
    (tokens, _comments, _ld, lex_errs) = ct_lexer.tokenize_full(src_txt, key);
    parser = Parser(tokens=tokens, file_path=key, source_code=src_txt);
    module = parser.parse();
    if parser.error_count > 0 or lex_errs > 0 {
        raise ValueError(f"reflect: parse errors in {key}");
    }
    info = CtModuleInfo(path=key);
    _collect_types(info, module);
    _MODULE_CACHE[key] = info;
    return info;
}


def _collect_types(info: CtModuleInfo, module: Module) {
    for item in module.body {
        if isinstance(item, Archetype) {
            ti = CtTypeInfo(name=item.name.value, bases=_base_names(item));
            body = item.body if item.body is not None else [];
            for stmt in body {
                if isinstance(stmt, ArchHas) {
                    ti.fields.extend(_field_infos(stmt));
                } elif isinstance(stmt, Ability)
                    and isinstance(stmt.name_ref, Name)
                    and stmt.name_ref.value == "init" {
                    ti.has_explicit_init = True;
                    ti.init_params = _init_param_infos(stmt);
                }
            }
            info.types[ti.name] = ti;
            info.order.append(ti.name);
        } elif isinstance(item, Enum) {
            ti = CtTypeInfo(
                name=item.name.value, is_enum=True, members=_enum_member_names(item)
            );
            info.types[ti.name] = ti;
            info.order.append(ti.name);
        }
    }
}


def _c3(info: CtModuleInfo, name: str) -> list[str] {
    ti = info.types.get(name);
    if ti is None {
        return [name];
    }
    if not ti.bases {
        return [name];
    }
    seqs: list[list[str]] = [];
    for b in ti.bases {
        seqs.append(_c3(info, b));
    }
    seqs.append(list(ti.bases));
    out: list[str] = [name];
    while True {
        seqs = [
            s
            for s in seqs
            if s
        ];
        if not seqs {
            return out;
        }
        cand = "";
        for s in seqs {
            head = s[0];
            in_tail = False;
            for s2 in seqs {
                if head in s2[1:] {
                    in_tail = True;
                    break;
                }
            }
            if not in_tail {
                cand = head;
                break;
            }
        }
        if not cand {
            raise ValueError(f"reflect: inconsistent MRO for {name}");
        }
        out.append(cand);
        for s in seqs {
            if s and s[0] == cand {
                s.pop(0);
            }
        }
    }
}
