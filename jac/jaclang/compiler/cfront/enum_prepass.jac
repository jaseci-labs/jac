import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.cfront.c_common { eval_enumerators, EnumPairs }

enum EnumShape {
    NONE = "none",
    ENUM_AS_ENUM = "enum_as_enum",
    ENUM_AS_CONSTS = "enum_as_consts"
}

glob _INT_USE_BINOPS: set[str] = {
         "|",
         "&",
         "^",
         "<<",
         ">>",
         "+",
         "-",
         "*",
         "/",
         "%"
     };

obj EnumVerdicts {
    has verdicts: dict[int, EnumShape],
        name_map: dict[int, dict[str, int]],
        reasons: dict[int, str];

    def init {
        self.verdicts = {};
        self.name_map = {};
        self.reasons = {};
    }
}

def _collect_tu_names(file_ast: object) -> set[str] {
    names: set[str] = set();
    ext = getattr(file_ast, "ext");
    if ext is None {
        return names;
    }
    for entry in ext {
        if isinstance(entry, c_ast.FuncDef) {
            decl = getattr(entry, "decl");
            nm = getattr(decl, "name") if decl is not None else None;
            if nm {
                names.add(nm);
            }
        } elif isinstance(entry, c_ast.Decl) or isinstance(entry, c_ast.Typedef) {
            nm = getattr(entry, "name");
            if nm {
                names.add(nm);
            }
        }
    }
    return names;
}

def _collect_int_use_names(nd: object, names: set[str]) {
    if isinstance(nd, c_ast.BinaryOp) and nd.op in _INT_USE_BINOPS {
        for operand in (nd.left, nd.right) {
            if isinstance(operand, c_ast.ID) {
                names.add(operand.name);
            }
        }
    }
    if isinstance(nd, c_ast.UnaryOp) and nd.op == "~" {
        if isinstance(nd.expr, c_ast.ID) {
            names.add(nd.expr.name);
        }
    }
    for (_, child) in nd.children() {
        _collect_int_use_names(child, names);
    }
}

def _enum_explicit_values(enumerator_list: object) -> dict[str, int] | None {
    ep: EnumPairs = eval_enumerators(enumerator_list);
    if not ep.all_simple {
        return None;
    }
    result: dict[str, int] = {};
    for (nm, v) in ep.pairs {
        result[nm] = v;
    }

    vals = list(result.values());
    if len(vals) != len(set(vals)) {
        return None;
    }

    return result;
}

def _collect_enums(nd: object, results: list[object]) {
    if isinstance(nd, c_ast.Enum) {
        results.append(nd);
    }
    for (_, child) in nd.children() {
        _collect_enums(child, results);
    }
}

def _classify_enum(
    en: object, seen_glob_names: set[str], int_use_names: set[str]
) -> tuple[EnumShape, dict[str, int] | None, str] {
    name_map = _enum_explicit_values(en.values);
    used_as_int = name_map is not None and any(nm in int_use_names for nm in name_map);
    if en.name is not None and name_map is not None and not used_as_int {
        return (EnumShape.ENUM_AS_ENUM, name_map, "");
    }
    if name_map is not None {
        if any(nm in seen_glob_names for nm in name_map) {
            return (
                EnumShape.NONE,
                None,
                "enumerator name collides with an existing module global"
            );
        }
        for nm in name_map {
            seen_glob_names.add(nm);
        }
        return (EnumShape.ENUM_AS_CONSTS, name_map, "");
    }
    ep2: EnumPairs = eval_enumerators(en.values);
    best_map: dict[str, int] = {};
    for (nm, v) in ep2.pairs {
        best_map[nm] = v;
    }
    collision = any(nm in seen_glob_names for nm in best_map);
    if not ep2.all_simple or collision {
        reason = "enumerator name collides with an existing module global"
            if collision
            else "enum has non-constant enumerator values";
        return (EnumShape.NONE, None, reason);
    }
    for nm in best_map {
        seen_glob_names.add(nm);
    }
    return (EnumShape.ENUM_AS_CONSTS, best_map, "");
}

def build_enum_map(file_ast: object) -> EnumVerdicts {
    ev = EnumVerdicts();
    enums: list[object] = [];
    _collect_enums(file_ast, enums);

    seen_glob_names: set[str] = _collect_tu_names(file_ast);

    int_use_names: set[str] = set();
    _collect_int_use_names(file_ast, int_use_names);
    for en in enums {
        if en.values is None {
            continue;
        }
        (verdict, nm_map, reason) = _classify_enum(en, seen_glob_names, int_use_names);
        ev.verdicts[id(en)] = verdict;
        if nm_map is not None {
            ev.name_map[id(en)] = nm_map;
        }
        if reason {
            ev.reasons[id(en)] = reason;
        }
    }
    return ev;
}
