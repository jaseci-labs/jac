"""Implementation of JSDoc generation from typed Jac signatures."""

import re;
import from jaclang.jac0core.unitree { Module, Ability }

# Scalar Jac type -> JSDoc/TS type. None maps contextually (see jac_type_to_jsdoc).
glob _SCALAR_MAP: dict[str, str] = {
         "int": "number",
         "float": "number",
         "complex": "number",
         "str": "string",
         "bytes": "string",
         "bytearray": "string",
         "bool": "boolean",
         "any": "*",
         "Any": "*",
         "object": "*",

     };

"""Split `s` on `sep` only at bracket depth 0 (so `dict[a, b]` is not split on its inner comma)."""
def _split_top(s: str, sep: str) -> list[str] {
    parts: list[str] = [];
    depth = 0;
    buf: list[str] = [];
    for ch in s {
        if ch in "[(" {
            depth += 1;
            buf.append(ch);
        } elif ch in ")]" {
            depth -= 1;
            buf.append(ch);
        } elif ch == sep and depth == 0 {
            parts.append("".join(buf));
            buf = [];
        } else {
            buf.append(ch);
        }
    }
    parts.append("".join(buf));
    return parts;
}

# Shared Jac->type-string mapping for both JSDoc and TypeScript declarations.
# `ts=True` emits idiomatic TS (`any`, `Record<K,V>`); `ts=False` emits JSDoc
# (`*`, `Object<K,V>`). The two dialects are otherwise identical.
def _map_type(type_str: str, is_return: bool, ts: bool) -> str {
    s = type_str.strip();
    any_t = "any" if ts else "*";
    if not s {
        return any_t;
    }

    # Unions: A | B | None  ->  (A|B|null)
    union_parts = _split_top(s, "|");
    if len(union_parts) > 1 {
        mapped = [_map_type(p, False, ts) for p in union_parts];
        return "(" + "|".join(mapped) + ")";
    }

    # Generics: list[...], dict[...], Optional[...], custom[...]
    if s.endswith("]") and "[" in s {
        base = s[:s.index("[")].strip();
        inner = s[s.index("[") + 1:-1];
        args = [a.strip() for a in _split_top(inner, ",")];
        if base in (
            "list",
            "List",
            "Sequence",
            "Iterable",
            "set",
            "Set",
            "frozenset"
        ) {
            elem = _map_type(args[0], False, ts) if args and args[0] else any_t;
            return f"Array<{elem}>";
        }
        if base in ("tuple", "Tuple") {
            if not args or args == [""] {
                return f"Array<{any_t}>";
            }
            if "..." in args {
                return f"Array<{_map_type(args[0], False, ts)}>";
            }
            return "[" + ", ".join(_map_type(a, False, ts) for a in args) + "]";
        }
        if base in ("dict", "Dict", "Mapping", "Record") {
            key = _map_type(args[0], False, ts) if len(args) > 0 else "string";
            val = _map_type(args[1], False, ts) if len(args) > 1 else any_t;
            return f"Record<{key}, {val}>" if ts else f"Object<{key}, {val}>";
        }
        if base in ("Optional", ) {
            return f"({_map_type(args[0], False, ts)}|null)" if args else any_t;
        }
        # Unknown generic (e.g. a user Generic[T]) -> use the base identifier.
        return base;
    }

    if s in ("None", "NoneType") {
        return "void" if is_return else "null";
    }
    if s in _SCALAR_MAP {
        mapped = _SCALAR_MAP[s];
        return "any" if (ts and mapped == "*") else mapped;
    }
    if s in ("list", "List") {
        return f"Array<{any_t}>";
    }
    if s in ("dict", "Dict") {
        return "Record<string, any>" if ts else "Object";
    }
    # Custom class / archetype name passes through verbatim.
    return s;
}

impl jac_type_to_jsdoc(type_str: str, is_return: bool = False) -> str {
    return _map_type(type_str, is_return, False);
}

impl jac_type_to_ts(type_str: str, is_return: bool = False) -> str {
    return _map_type(type_str, is_return, True);
}

def _param_type(param: any) -> str | None {
    tag = param?.type_tag;
    if tag is None {
        return None;
    }
    inner = tag?.tag;
    if inner is None or not hasattr(inner, "unparse") {
        return None;
    }
    try {
        return inner.unparse();
    } except Exception {
        return None;
    }
}

def _block_for_ability(ability: Ability) -> str | None {
    sig = ability?.signature;
    lines: list[str] = ["/**"];
    has_content = False;

    params = sig?.params if sig else None;
    if params {
        for p in params {
            pname = p?.sym_name or p?.name;
            if pname is None {
                continue;
            }
            ptype = _param_type(p);
            jsdoc_t = jac_type_to_jsdoc(ptype) if ptype else "*";
            lines.append(f" * @param {{{jsdoc_t}}} {pname}");
            has_content = True;
        }
    }

    ret = sig?.return_type if sig else None;
    if ret is not None and hasattr(ret, "unparse") {
        try {
            rt_str = ret.unparse();
        } except Exception {
            rt_str = "";
        }
        if rt_str {
            jsdoc_rt = jac_type_to_jsdoc(rt_str, is_return=True);
            if jsdoc_rt != "void" {
                lines.append(f" * @returns {{{jsdoc_rt}}}");
                has_content = True;
            }
        }
    }

    if not has_content {
        return None;
    }
    lines.append(" */");
    return "\n".join(lines);
}

impl jsdoc_for_module(mod: Module) -> dict[str, str] {
    blocks: dict[str, str] = {};
    for nd in mod.body {
        if isinstance(nd, Ability) {
            name = nd?.sym_name;
            if not name {
                continue;
            }
            block = _block_for_ability(nd);
            if block is not None {
                blocks[name] = block;
            }
        }
    }
    return blocks;
}

impl inject_jsdoc(js: str, blocks: dict[str, str]) -> str {
    out = js;
    for (name, block) in blocks.items() {
        pattern = re.compile(
            r"(?m)^([ \t]*)((?:export\s+)?(?:async\s+)?(?:function|class)\s+" + re.escape(
                name
            ) + r"\b)"
        );

        def _repl(m: any) -> str {
            indent = m.group(1);
            indented = "\n".join(
                (indent + line) if line else line for line in block.split("\n")
            );
            return indented + "\n" + m.group(0);
        }
        (out, n) = pattern.subn(_repl, out, count=1);
    }
    return out;
}
