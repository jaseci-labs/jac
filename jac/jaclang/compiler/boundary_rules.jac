import from jaclang.compiler.frontend.unitree { Ability, FuncSignature }
import from jaclang.compiler.capability_notes {
    TARGET_CLIENT,
    TARGET_NATIVE,
    TARGET_SERVER
}

glob PYTHON_NATIVE_WIRE: tuple[str, ...] = ('int', 'float', 'bool', 'str'),
     NEVER_ON_THE_WIRE: tuple[str, ...] = (
         'Region',
         'Callable',
         'Iterator',
         'Generator',
         'TextIO',
         'BinaryIO'
     );

def python_native_wire -> set[str] {
    import from jaclang.runtime.scalars { sized_scalar_names }
    return set(PYTHON_NATIVE_WIRE) | set(sized_scalar_names());
}

def crossing_refusal(
    type_name: str, src: str, dst: str, is_return: bool = False
) -> (str | None) {
    if src == dst {
        return None;
    }
    spelled = type_name.strip();
    if TARGET_NATIVE in (src, dst) {
        if is_return and spelled in ('None', 'NoneType', '') {
            return None;
        }
        if spelled in python_native_wire() {
            return None;
        }
        return f"'{spelled}' is not one of the scalars that cross between native "
        f"and {dst if src == TARGET_NATIVE else src} code";
    }
    for banned in NEVER_ON_THE_WIRE {
        if spelled == banned or spelled.startswith(banned + '[') {
            return f"'{spelled}' has no wire form between {src} and {dst} code";
        }
    }
    return None;
}

def signature_crossings(
    param_names: list[str], param_types: list[str], ret_type: str, src: str, dst: str
) -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    for (index, spelled) in enumerate(param_types) {
        why = crossing_refusal(spelled, src, dst);
        if why is not None {
            pname = param_names[index] if index < len(param_names) else str(index);
            out.append((f"parameter '{pname}'", spelled, why));
        }
    }
    why = crossing_refusal(ret_type, src, dst, True);
    if why is not None {
        out.append(("the return", ret_type, why));
    }
    return out;
}

def ability_crossing(decl: Ability, src: str, dst: str) -> (str | None) {
    import from jaclang.compiler.frontend.unparse { unparse_node }
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) or decl.method_owner is not None {
        return "only a module-level function can be called across codespaces";
    }
    names: list[str] = [];
    spelled: list[str] = [];
    for p in sig.get_parameters() {
        names.append(p.name.value);
        tag = p.type_tag.tag if p.type_tag is not None else None;
        spelled.append(unparse_node(tag) if tag is not None else 'any');
    }
    ret = sig.return_type;
    found = signature_crossings(
        names, spelled, unparse_node(ret) if ret is not None else 'None', src, dst
    );
    if found {
        (what, _spelled, why) = found[0];
        return f"{what}: {why}";
    }
    return None;
}
