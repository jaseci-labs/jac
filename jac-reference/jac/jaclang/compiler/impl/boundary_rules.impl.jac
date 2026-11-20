impl python_native_wire -> set[str] {
    return set(PYTHON_NATIVE_WIRE) | set(sized_scalar_names());
}

impl crossing_refusal(
    type_name: str, src: str, dst: str, is_return: bool = False, placing: bool = False
) -> (str | None) {
    if src == dst or TARGET_NATIVE not in (src, dst) {
        return None;
    }
    spelled = type_name.strip();
    if is_return and spelled in ('None', 'NoneType', '') {
        return None;
    }
    if placing and spelled == 'str' {
        return "a 'str' is not converted by the call bridge between native and "
        "Python code, so a call that passes one is not placed across it";
    }
    if spelled in python_native_wire() {
        return None;
    }
    return f"'{spelled}' is not one of the scalars that cross between native "
    f"and {dst if src == TARGET_NATIVE else src} code";
}

impl signature_crossings(
    param_names: list[str],
    param_types: list[str],
    ret_type: str,
    src: str,
    dst: str,
    placing: bool = False
) -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    for (index, spelled) in enumerate(param_types) {
        why = crossing_refusal(spelled, src, dst, False, placing);
        if why is not None {
            pname = param_names[index] if index < len(param_names) else str(index);
            out.append((f"parameter '{pname}'", spelled, why));
        }
    }
    why = crossing_refusal(ret_type, src, dst, True, placing);
    if why is not None {
        out.append(("the return", ret_type, why));
    }
    return out;
}

impl annotation_shape(tag: (UniNode | None)) -> tuple[str, list[UniNode]] {
    if tag is None {
        return ('any', []);
    }
    if isinstance(tag, Null) {
        return ('None', []);
    }
    if isinstance(tag, Ellipsis) {
        return ('...', []);
    }
    if isinstance(tag, AtomUnit) {
        return annotation_shape(tag.value);
    }
    if isinstance(tag, String) {
        return (tag.value.strip('"').strip("'"), []);
    }
    if isinstance(tag, Token) {
        return (tag.value, []);
    }
    if isinstance(tag, BinaryExpr) {
        op = tag.op;
        if isinstance(op, Token) and op.value == '|' {
            return ('|', [tag.left, tag.right]);
        }
        return ('', []);
    }
    if isinstance(tag, AtomTrailer) {
        if tag.is_attr {
            return annotation_shape(tag.right);
        }
        (head, _inner) = annotation_shape(tag.target);
        args: list[UniNode] = [];
        if isinstance(tag.right, IndexSlice) {
            for part in tag.right.slices {
                start = part.start;
                if isinstance(start, TupleVal) {
                    args.extend(start.values);
                } elif start is not None {
                    args.append(start);
                }
            }
        }
        return (head, args);
    }
    return ('', []);
}

impl declared_type(scope: (Module | None), name: str) -> (Archetype | Enum | None) {
    if scope is None or scope.sym_tab is None {
        return None;
    }
    sym = scope.sym_tab.lookup(name, deep=True);
    if sym is None or not sym.defn {
        return None;
    }
    found: (UniNode | None) = sym.defn[0];
    if isinstance(found, NameAtom) and found.parent is not None {
        found = found.parent;
    }
    if isinstance(found, (Archetype, Enum)) {
        return found;
    }
    resolved = resolved_decl_of(sym);
    target = resolved.name_of if resolved is not None else None;
    return target if isinstance(target, (Archetype, Enum)) else None;
}

impl alias_value(scope: (Module | None), name: str) -> (UniNode | None) {
    if scope is None or scope.sym_tab is None {
        return None;
    }
    sym = scope.sym_tab.lookup(name, deep=True);
    if sym is None {
        return None;
    }
    found: (UniNode | None) = sym.defn[0] if sym.defn else None;
    resolved = resolved_decl_of(sym);
    if resolved is not None {
        found = resolved;
    }
    if isinstance(found, NameAtom) {
        if isinstance(found.name_of, TypeAlias) {
            return found.name_of.value;
        }
        if isinstance(found.parent, Assignment) {
            return found.parent.value;
        }
    }
    return None;
}

impl non_string_key(
    tag: (UniNode | None), scope: (Module | None), depth: int
) -> (str | None) {
    (key, key_args) = annotation_shape(tag);
    if key in ('', '...', 'str', 'any', 'Any') {
        return None;
    }
    if key in ('|', 'Union', 'Optional') {
        for branch in key_args {
            bad = non_string_key(branch, scope, depth);
            if bad is not None {
                return bad;
            }
        }
        return 'None' if key == 'Optional' else None;
    }
    if key == 'Literal' {
        for value in key_args {
            if not isinstance(value, (String, MultiString)) {
                return key;
            }
        }
        return None;
    }
    if key in JSON_SCALARS
        or key in sized_scalar_names()
        or key in JSON_SEQUENCES
        or key in JSON_MAPPINGS {
        return key;
    }
    if depth < 8 {
        target = alias_value(scope, key);
        if target is not None {
            return non_string_key(target, scope, depth + 1);
        }
    }
    if declared_type(scope, key) is not None {
        return key;
    }
    return None;
}

impl json_refusal(
    tag: (UniNode | None),
    scope: (Module | None),
    is_return: bool,
    to_server: bool,
    seen: set[str]
) -> (tuple[str, str] | None) {
    (head, args) = annotation_shape(tag);
    spelled = unparse_node(tag) if tag is not None else 'any';
    if head == '' or head == '...' {
        return None;
    }
    if head == '|' {
        for branch in args {
            why = json_refusal(branch, scope, is_return, to_server, seen);
            if why is not None {
                return why;
            }
        }
        return None;
    }
    if head in JSON_SCALARS or head in sized_scalar_names() {
        return None;
    }
    if head in JSON_SEQUENCES {
        for item in args {
            why = json_refusal(item, scope, is_return, to_server, seen);
            if why is not None {
                return why;
            }
        }
        return None;
    }
    if head in JSON_MAPPINGS {
        if len(args) > 0 {
            key = non_string_key(args[0], scope, 0);
            if key is not None {
                return (
                    spelled,
                    f"a JSON object has string keys, so '{key}' keys arrive as "
                    f"strings on the other side"
                );
            }
        }
        if len(args) > 1 {
            return json_refusal(args[1], scope, is_return, to_server, seen);
        }
        return None;
    }
    if head in REQUEST_PARTS {
        if is_return or not to_server {
            return (
                spelled,
                f"'{head}' is a part of a request; only a parameter of a server "
                f"function can receive one"
            );
        }
        return None;
    }
    if head in STREAMED_RESULTS {
        if not is_return {
            return (
                spelled,
                f"'{head}' crosses only as a streamed result; a parameter is "
                f"bound once from the request"
            );
        }
        if len(args) > 0 {
            return json_refusal(args[0], scope, is_return, to_server, seen);
        }
        return None;
    }
    decl = declared_type(scope, head);
    if isinstance(decl, Enum) {
        return None;
    }
    if isinstance(decl, Archetype) {
        if decl.in_native_context() {
            return (
                spelled,
                f"'{head}' is a native object and is opaque outside native code"
            );
        }
        if head in seen {
            return None;
        }
        seen.add(head);
        for (field, field_home) in archetype_fields(decl) {
            inner = field.type_tag.tag if field.type_tag is not None else None;
            why = json_refusal(inner, field_home or scope, is_return, to_server, seen);
            if why is not None {
                (inner_spelled, reason) = why;
                return (
                    spelled,
                    f"its field '{field.sym_name}: {inner_spelled}' does not "
                    f"cross ({reason})"
                );
            }
        }
        return None;
    }
    if head in NOT_DATA {
        return (
            spelled,
            f"'{head}' is behaviour or a handle, not data; the request binder "
            f"cannot build one and the response serializer cannot write one"
        );
    }
    return None;
}

impl signature_refusals(
    decl: Ability, src: str, dst: str, placing: bool = False
) -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) or src == dst {
        return out;
    }
    scope = decl.find_parent_of_type(Module);
    ret = sig.return_type;
    if TARGET_NATIVE in (src, dst) {
        names: list[str] = [];
        spelled: list[str] = [];
        for p in sig.get_parameters() {
            names.append(p.name.value);
            tag = p.type_tag.tag if p.type_tag is not None else None;
            spelled.append(unparse_node(tag) if tag is not None else 'any');
        }
        return signature_crossings(
            names,
            spelled,
            unparse_node(ret) if ret is not None else 'None',
            src,
            dst,
            placing
        );
    }
    callee_is_server = dst == TARGET_SERVER;
    for p in sig.get_parameters() {
        tag = p.type_tag.tag if p.type_tag is not None else None;
        why = json_refusal(tag, scope, False, callee_is_server, set());
        if why is not None {
            out.append((f"parameter '{p.name.value}'", why[0], why[1]));
        }
    }
    why = json_refusal(ret, scope, True, not callee_is_server, set())
        if ret is not None
        else None;
    if why is not None {
        out.append(("the return", why[0], why[1]));
    }
    return out;
}

impl archetype_refusals(
    decl: Archetype, src: str, dst: str
) -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    if src == dst or TARGET_NATIVE in (src, dst) {
        return out;
    }
    for (field, home) in archetype_fields(decl) {
        tag = field.type_tag.tag if field.type_tag is not None else None;
        why = json_refusal(tag, home, False, dst == TARGET_SERVER, {decl.sym_name});
        if why is not None {
            out.append((f"field '{field.sym_name}'", why[0], why[1]));
        }
    }
    return out;
}

impl archetype_fields(decl: Archetype) -> list[tuple[HasVar, (Module | None)]] {
    out: list[tuple[HasVar, (Module | None)]] = [];
    seen: set[int] = set();
    pending: list[Archetype] = [decl];
    while pending {
        current = pending.pop(0);
        if id(current) in seen {
            continue;
        }
        seen.add(id(current));
        home = current.find_parent_of_type(Module);
        for field in current.get_has_vars() {
            out.append((field, home));
        }
        for base in current.base_classes {
            parent = referenced_archetype(base);
            if parent is not None {
                pending.append(parent);
            }
        }
    }
    return out;
}

impl ability_crossing(decl: Ability, src: str, dst: str) -> (str | None) {
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) or decl.method_owner is not None {
        return "only a module-level function can be called across codespaces";
    }
    found = signature_refusals(decl, src, dst, True);
    if found {
        (what, _spelled, why) = found[0];
        return f"{what}: {why}";
    }
    if src == TARGET_SERVER and dst == TARGET_NATIVE {
        for param in sig.get_parameters() {
            if param.value is not None {
                return f"parameter '{param.name.value}' has a default, which the "
                "Python stub for a native function does not carry";
            }
        }
    }
    return None;
}
