"""Implementation of MTIR spec extraction for test generation."""

import hashlib;
import json;
import from jaclang.jac0core.mtp {
    FunctionInfo, MethodInfo, ClassInfo, EnumInfo, FieldInfo, ParamInfo,
    type_to_str
}

"""Recursively resolve a type_info value into (type_str, ClassSpec|EnumSpec|None).

Handles:
  - str primitives: ("str", None)
  - ClassInfo: ("ClassName", ClassSpec(...))
  - EnumInfo: ("EnumName", EnumSpec(...))
  - tuple generics ('list', inner), ('dict', k, v), ('union', ...): (type_to_str(t), first nested detail)
"""
def _resolve_type(type_info: object, depth: int = 0) -> tuple {
    if type_info is None {
        return ("None", None);
    }
    if isinstance(type_info, str) {
        return (type_info, None);
    }
    if isinstance(type_info, EnumInfo) {
        members: list[tuple] = [];
        for m in (type_info.members or []) {
            members.append((m.name, m.semstr));
        }
        return (
            type_info.name,
            EnumSpec(name=type_info.name, semstr=type_info.semstr, members=members)
        );
    }
    if isinstance(type_info, ClassInfo) {
        if depth >= 3 {
            # depth-limit to avoid infinite recursion on self-referential types
            return (type_info.name, None);
        }
        fields: list[FieldSpec] = [];
        for f in (type_info.fields or []) {
            (ftype_str, _) = _resolve_type(f.type_info, depth + 1);
            fields.append(FieldSpec(name=f.name, type_str=ftype_str, semstr=f.semstr));
        }
        return (
            type_info.name,
            ClassSpec(name=type_info.name, semstr=type_info.semstr, fields=fields)
        );
    }
    if isinstance(type_info, tuple) {
        type_str = type_to_str(type_info);
        # Try to find the first ClassInfo or EnumInfo inside the tuple for nested detail
        nested_detail = None;
        for inner in type_info[1:] {
            if isinstance(inner, (ClassInfo, EnumInfo)) {
                (_, nested_detail) = _resolve_type(inner, depth + 1);
                break;
            }
        }
        return (type_str, nested_detail);
    }
    # Fallback: convert unknown to string
    return (str(type_info), None);
}

def _class_spec_sig(spec: ClassSpec) -> object {
    return {
        "name": spec.name,
        "semstr": spec.semstr,
        "fields": [(f.name, f.type_str, f.semstr) for f in spec.fields],
    };
}

def _enum_spec_sig(spec: EnumSpec) -> object {
    return {
        "name": spec.name,
        "semstr": spec.semstr,
        "members": spec.members,
    };
}

def _detail_sig(detail: object) -> object {
    if isinstance(detail, ClassSpec) {
        return _class_spec_sig(detail);
    }
    if isinstance(detail, EnumSpec) {
        return _enum_spec_sig(detail);
    }
    return None;
}

def _param_sig(p: ParamSpec) -> object {
    return (p.name, p.type_str, p.semstr, _detail_sig(p.nested));
}

impl FunctionSpec.spec_hash -> str {
    payload = {
        "name": self.name,
        "semstr": self.semstr,
        "params": [_param_sig(p) for p in self.params],
        "return_type_str": self.return_type_str,
        "return_type_detail": _detail_sig(self.return_type_detail),
    };
    raw = json.dumps(payload, sort_keys=True).encode();
    return hashlib.sha256(raw).hexdigest()[:16];
}

impl extract_specs(mtir_map: dict) -> list[FunctionSpec] {
    specs: list[FunctionSpec] = [];
    for (key, info) in mtir_map.items() {
        # Only process FunctionInfo entries. MTIR captures ALL `by <expr>()` abilities
        # regardless of model name (by llm(), by my_model(), by models["x"](), etc.)
        # MethodInfo is a subclass of FunctionInfo; we include those too.
        # Skip entries flagged as pure tools (by_call=True means called as a tool, not tested directly).
        if not isinstance(info, FunctionInfo) {
            continue;
        }
        if info.by_call {
            # This entry was registered as a tool target, not a standalone callable
            continue;
        }

        # Resolve return type
        (return_type_str, return_type_detail) = _resolve_type(info.return_type);

        # Resolve params
        params: list[ParamSpec] = [];
        for p in (info.params or []) {
            (ptype_str, pnested) = _resolve_type(p.type_info);
            params.append(ParamSpec(
                name=p.name,
                type_str=ptype_str,
                semstr=p.semstr,
                nested=pnested
            ));
        }

        # Extract just the function name from the qualified key
        # key format: "module.qualname" (e.g. "llm_semstrings.generate_password"
        #             or "module.ClassName.method")
        parts = key.rsplit(".", 1);
        name = parts[-1] if len(parts) > 1 else key;

        # Detect methods: MethodInfo has a parent_class attribute
        parent_class: str | None = None;
        if isinstance(info, MethodInfo) and info.parent_class {
            parent_class = info.parent_class.name;
        }

        specs.append(FunctionSpec(
            qualified_key=key,
            name=name,
            parent_class=parent_class,
            semstr=info.semstr,
            params=params,
            return_type_str=return_type_str,
            return_type_detail=return_type_detail
        ));
    }
    return specs;
}
