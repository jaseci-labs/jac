impl Question.to_wire -> dict[str, any] {
    wire: dict[str, any] = {"type": self.kind, "instructions": self.instructions};
    if self.criteria is not None {
        wire["criteria"] = self.criteria;
    }
    return wire;
}


impl SystemOneSpec.to_payload(model: str) -> dict[str, any] {
    return {
        "model": model,
        "state": self.state,
        "questions": {k: q.to_wire() for (k, q) in self.questions.items()}
    };
}


impl default_caps -> ProviderCaps {
    return ProviderCaps();
}


impl enum_info_of(resp_type: object, info: object) -> (EnumInfo | None) {
    if not (isinstance(resp_type, type) and issubclass(resp_type, Enum)) {
        return None;
    }
    if isinstance(info, EnumInfo) {
        return info;
    }
    if isinstance(info, VarInfo) and isinstance(info.type_info, EnumInfo) {
        return info.type_info;
    }
    return None;
}


impl return_info_of(mt_run: MTRuntime) -> object {
    owner = mt_run.mtir;
    owner_info = owner.ir_info if owner else None;
    return owner_info.return_type if isinstance(owner_info, FunctionInfo) else None;
}


impl instructions_of(mt_run: MTRuntime) -> str {
    owner = mt_run.mtir;
    owner_info = owner.ir_info if owner else None;
    if isinstance(owner_info, FunctionInfo) {
        if owner_info.semstr {
            return owner_info.semstr;
        }
        if owner_info.name {
            return str(owner_info.name).strip("_").replace("_", " ");
        }
    }
    if owner is not None {
        name = str(getattr(owner.caller, "__name__", "") or "");
        if name {
            return name.strip("_").replace("_", " ");
        }
    }
    for msg in mt_run.messages {
        if isinstance(msg, dict) {
            role = msg.get("role");
            content = msg.get("content");
        } else {
            role = msg?.role;
            content = msg?.content;
        }
        role_s = str(role?.value or role or "");
        if role_s == "system" and isinstance(content, str) and content.strip() {
            return content.strip();
        }
    }
    return "Choose the value the program should receive.";
}


def _state_value(value: object) -> object {
    import from jaclang.runtime.object_interop { fields as record_fields, is_record }

    if value is None or isinstance(value, (str, int, float, bool)) {
        return value;
    }
    if isinstance(value, Enum) {
        return value.name;
    }
    if isinstance(value, dict) {
        return {str(k): _state_value(v) for (k, v) in value.items()};
    }
    if isinstance(value, (list, tuple, set)) {
        return [_state_value(v) for v in value];
    }
    if not isinstance(value, type) and is_record(value) {
        out: dict[str, any] = {};
        for f in record_fields(value) {
            name = str(f.name);
            if not name.startswith("_") {
                out[name] = _state_value(getattr(value, name, None));
            }
        }
        return out;
    }
    return repr(value);
}


def _messages_text(mt_run: MTRuntime) -> str {
    parts: list[str] = [];
    for msg in mt_run.get_msg_list() {
        content = msg.get("content") if isinstance(msg, dict) else None;
        if isinstance(content, str) and content {
            parts.append(content);
        }
    }
    return "\n\n".join(parts);
}


impl build_state(mt_run: MTRuntime) -> (dict[str, any] | None) {
    import from jaclang.byllm.types { Media }

    owner = mt_run.mtir;
    if owner is None {
        text = _messages_text(mt_run);
        return {"context": text} if text else None;
    }

    owner_info = owner.ir_info if isinstance(owner.ir_info, FunctionInfo) else None;
    params = (owner_info.params if owner_info else None) or [];

    state: dict[str, any] = {};
    for (idx, key) in enumerate(list(owner.args.keys())) {
        value = owner.args[key];
        if isinstance(value, Media) {
            return None;
        }
        if isinstance(key, str) {
            name = key;
        } elif idx < len(params) {
            name = params[idx].name;
        } else {
            name = f"arg{idx}";
        }
        state[str(name)] = _state_value(value);
    }

    caller = owner.caller;
    if isinstance(caller, MethodType) {
        state["self"] = _state_value(caller.__self__);
    }
    incl_info = (owner.call_params or {}).get("incl_info");
    if isinstance(incl_info, dict) {
        for (key, value) in incl_info.items() {
            if isinstance(value, Media) {
                return None;
            }
            state[str(key)] = _state_value(value);
        }
    }
    return state;
}


def _canonical_names(enum_type: object) -> list[str] {
    try {
        return [str(getattr(m, "name", m)) for m in list(enum_type)];
    } except Exception {
        return list(getattr(enum_type, "__members__", {}).keys());
    }
}


def _lower_enum(
    resp_type: object,
    enum_info: (EnumInfo | None),
    instructions: str,
    caps: ProviderCaps
) -> (Question | None) {
    described: dict[str, any] = {};
    for member in ((enum_info.members if enum_info else None) or []) {
        described[member.name] = member.semstr or None;
    }
    criteria: dict[str, any] = {};
    for name in _canonical_names(resp_type) {
        criteria[name] = described.get(name);
    }
    if len(criteria) < 2 or len(criteria) > caps.max_choice_options {
        return None;
    }
    return Question(kind=CHOICE, instructions=instructions, criteria=criteria);
}


def _lower_bool(instructions: str) -> Question {
    return Question(kind=NOUL, instructions=instructions, criteria=None);
}


def _list_enum_inner(resp_type: object) -> (type | None) {
    import from typing { get_args, get_origin }

    if get_origin(resp_type) is not list {
        return None;
    }
    args = get_args(resp_type);
    if len(args) != 1 {
        return None;
    }
    inner = args[0];
    if isinstance(inner, type) and issubclass(inner, Enum) {
        return inner;
    }
    return None;
}


def _list_inner_info(info: object) -> object {
    if isinstance(info, TypeForm) and info.head == "list" and info.args {
        return info.args[0];
    }
    return None;
}


def _lower_enum_list(
    inner: type, enum_info: (EnumInfo | None), instructions: str, caps: ProviderCaps
) -> dict[str, Question] {
    described: dict[str, any] = {};
    for member in ((enum_info.members if enum_info else None) or []) {
        described[member.name] = member.semstr or None;
    }
    names = _canonical_names(inner);
    if not names or len(names) > caps.max_choice_options or not caps.supports_batch {
        return {};
    }
    listed = ", ".join(names);
    out: dict[str, Question] = {};
    for name in names {
        text = described.get(name);
        yes = f"{name}: {text}" if text else name;
        out[name] = Question(
            kind=NOUL,
            instructions=(
                f"{instructions} The possible values are: {listed}. "
                f"Does {name} apply?"
            ),
            criteria={"true": yes, "false": None}
        );
    }
    return out;
}


def _unwrap_decision_info(info: object) -> object {
    if isinstance(info, TypeForm) and info.head == "Decision" and info.args {
        return info.args[0];
    }
    return info;
}


def _record_fields(t: object) -> dict[str, any] {
    import sys;
    import from typing { get_type_hints }
    import from jaclang.runtime.object_interop { fields as record_fields, is_record }

    if not isinstance(t, type) {
        return {};
    }
    declared: dict[str, any] = {};
    try {
        if is_record(t) {
            for f in record_fields(t) {
                declared[str(f.name)] = f?.type;
            }
        }
    } except Exception {
        declared = {};
    }
    resolved: dict[str, any] = {};
    try {
        resolved = dict(get_type_hints(t));
    } except Exception {
        resolved = {};
    }
    module_ns: dict[str, any] = {};
    mod = sys.modules.get(str(getattr(t, "__module__", "")));
    if mod is not None {
        module_ns = dict(vars(mod));
    }
    out: dict[str, any] = {};
    for (k, v) in (declared or resolved).items() {
        if str(k).startswith("_") {
            continue;
        }
        hint = resolved.get(k);
        if hint is None and isinstance(v, str) {
            hint = module_ns.get(v)
                or {"bool": bool, "int": int, "str": str, "float": float}.get(v);
        }
        out[str(k)] = hint if hint is not None else v;
    }
    return out;
}


def _is_record_type(t: object) -> bool {
    if not isinstance(t, type) {
        return False;
    }
    if issubclass(t, (Enum, Decision, str, int, float, bool, list, dict, tuple, set)) {
        return False;
    }
    return bool(_record_fields(t));
}


def _lower_record(
    t: type, info: object, instructions: str, caps: ProviderCaps
) -> dict[str, Question] {
    hints = _record_fields(t);
    if not hints or not caps.supports_batch {
        return {};
    }
    described: dict[str, any] = {};
    if isinstance(info, ClassInfo) {
        for f in (info.fields or []) {
            described[f.name] = f;
        }
    }
    out: dict[str, Question] = {};
    for (fname, ftype) in hints.items() {
        fi = described.get(fname);
        f_sem = fi.semstr if fi is not None else None;
        f_instr = f_sem or f"{instructions} What is {fname}?";
        if ftype is bool {
            out[fname] = Question(kind=NOUL, instructions=f_instr, criteria=None);
        } elif isinstance(ftype, type) and issubclass(ftype, Enum) {
            einfo = fi.type_info if fi is not None else None;
            q = _lower_enum(
                ftype, einfo if isinstance(einfo, EnumInfo) else None, f_instr, caps
            );
            if q is None {
                return {};
            }
            out[fname] = q;
        } else {
            return {};
        }
    }
    return out;
}


impl lower(
    mt_run: MTRuntime, caps: (ProviderCaps | None) = None
) -> (SystemOneSpec | None) {
    import from jaclang.byllm.types { image_resp_kind }

    caps = caps or default_caps();

    if mt_run.tools or mt_run.stream or image_resp_kind(mt_run.resp_type) {
        return None;
    }

    declared = mt_run.resp_type;
    if declared is None or declared is str {
        return None;
    }

    site_params = dict(mt_run.mtir.call_params or {}) if mt_run.mtir else {};
    site_params.update(mt_run.call_params or {});
    if site_params.get("conversation") is not None
        or site_params.get("system_prompt") {
        return None;
    }

    target: any = declared;
    wrap = False;
    if isinstance(declared, type) and issubclass(declared, Decision) {
        target = declared?._jac_inner;
        if target is None or target is str {
            return None;
        }
        wrap = True;
    }

    raw_info = return_info_of(mt_run);
    info = _unwrap_decision_info(raw_info) if wrap else raw_info;
    instructions = instructions_of(mt_run);
    questions: dict[str, Question] = {};
    mode = "";
    as_list = False;
    carried: any = target;
    route_select: any = "all";

    if target is bool {
        questions[ANSWER_KEY] = _lower_bool(instructions);
        mode = MODE_BOOL;
    } elif isinstance(target, type) and issubclass(target, Enum) {
        single = _lower_enum(target, enum_info_of(target, info), instructions, caps);
        if single is not None {
            questions[ANSWER_KEY] = single;
            mode = MODE_ENUM;
        }
    } else {
        inner = _list_enum_inner(target);
        if inner is not None {
            carried = inner;
            enum_info = enum_info_of(inner, _list_inner_info(info));
            select = getattr(mt_run, ROUTE_SELECT_ATTR, "all");
            route_select = select;
            if isinstance(select, int)
                and not isinstance(select, bool)
                and select == 1
                and len(_canonical_names(inner)) > 1 {
                one = _lower_enum(inner, enum_info, instructions, caps);
                if one is not None {
                    questions[ANSWER_KEY] = one;
                    mode = MODE_ENUM;
                    as_list = True;
                }
            } else {
                many = _lower_enum_list(inner, enum_info, instructions, caps);
                if many {
                    questions = many;
                    mode = MODE_ENUM_LIST;
                }
            }
        } elif _is_record_type(target) {
            per_field = _lower_record(target, info, instructions, caps);
            if per_field {
                questions = per_field;
                mode = MODE_RECORD;
            }
        }
    }

    if not questions {
        return None;
    }

    state = build_state(mt_run);
    if state is None {
        return None;
    }
    if len(repr(state)) > caps.max_state_chars {
        return None;
    }

    return SystemOneSpec(
        state=state,
        questions=questions,
        mode=mode,
        resp_type=carried,
        as_list=as_list,
        wrap_decision=wrap,
        select=route_select
    );
}


impl assemble(spec: SystemOneSpec, answers: dict[str, any]) -> tuple[object, float] {
    if spec.mode == MODE_ENUM_LIST {
        members = getattr(spec.resp_type, "__members__", {});
        ranked: list[tuple[float, int, object]] = [];
        seen: set[int] = set();
        boundary = 1.0;
        pos = 0;
        for name in _canonical_names(spec.resp_type) {
            member = members.get(name);
            if member is None or id(member) in seen {
                continue;
            }
            seen.add(id(member));
            a = answers.get(name);
            p = float(a.get("noul", 0.0)) if isinstance(a, dict) else 0.0;
            boundary = min(boundary, abs(2.0 * p - 1.0));
            ranked.append((p, -pos, member));
            pos += 1;
        }
        ranked.sort(reverse=True);
        above = [
            r
            for r in ranked
            if r[0] > 0.5
        ];
        sel = spec.select;
        take = above;
        exact = False;
        if isinstance(sel, int) and not isinstance(sel, bool) and sel >= 1 {
            take = ranked[:sel];
            exact = True;
        } elif isinstance(sel, tuple) and len(sel) == 2 {
            lo = int(sel[0]);
            hi = int(sel[1]);
            take = above[:hi];
            if len(take) < lo {
                take = ranked[:min(lo, len(ranked))];
            }
            exact = True;
        }
        conf = max(0.0, 2.0 * take[-1][0] - 1.0) if exact and take else boundary;
        return ([m for (_p, _i, m) in take], conf);
    }

    if spec.mode == MODE_RECORD {
        ctor = spec.resp_type;
        if ctor is None {
            raise OutputConversionError("record spec carries no type to rebuild");
        }
        hints = _record_fields(ctor);
        kwargs: dict[str, any] = {};
        worst = 1.0;
        for (fname, q) in spec.questions.items() {
            a = answers.get(fname);
            if not isinstance(a, dict) {
                raise OutputConversionError(
                    f"System One response carried no answer for field {fname!r}"
                );
            }
            ftype = hints.get(fname);
            if q.kind == NOUL {
                p = float(a.get("noul", 0.0));
                kwargs[fname] = p > 0.5;
                worst = min(worst, abs(2.0 * p - 1.0));
            } else {
                label = a.get("choice");
                members = getattr(ftype, "__members__", {});
                if label not in members {
                    raise OutputConversionError(
                        f"System One returned label {label!r} for field {fname!r}, "
                        f"which is not a member of {getattr(ftype, '__name__', '?')}"
                    );
                }
                kwargs[fname] = members[label];
                worst = min(worst, float(a.get("confidence", 0.0)));
            }
        }
        return (ctor(**kwargs), worst);
    }

    answer = answers.get(ANSWER_KEY);
    if not isinstance(answer, dict) {
        raise OutputConversionError(
            f"System One response carried no answer for {ANSWER_KEY!r}"
        );
    }

    if spec.mode == MODE_BOOL {
        p = float(answer.get("noul", 0.0));
        return (p > 0.5, abs(2.0 * p - 1.0));
    }

    if spec.mode == MODE_ENUM {
        name = answer.get("choice");
        members = getattr(spec.resp_type, "__members__", {});
        if name not in members {
            raise OutputConversionError(
                f"System One returned label {name!r}, which is not a member of "
                f"{getattr(spec.resp_type, '__name__', '?')}"
            );
        }
        chosen = members[name];
        return (
            [chosen] if spec.as_list else chosen,
            float(answer.get("confidence", 0.0))
        );
    }

    raise OutputConversionError(f"unknown System One lowering mode {spec.mode!r}");
}


impl wrap_result(
    spec: SystemOneSpec, value: object, confidence: float, probs: dict[str, any]
) -> object {
    if not spec.wrap_decision {
        return value;
    }
    return Decision(value=value, confidence=confidence, probabilities=probs);
}


impl providers -> dict[str, ProviderCaps] {
    return {
        "typesafe": ProviderCaps(
            base_url="https://api.typesafe.ai",
            key_env="TYPESAFE_API_KEY",
            key_env_aliases=["JEV_API_KEY"],
            model="jev-latest"
        ),
        "litellm": ProviderCaps(
            base_url="http://localhost:4000",
            key_env="LITELLM_API_KEY",
            key_env_aliases=["LITELLM_KEY"],
            model="jev-latest",
            route="/typesafe/v1/systemone"
        ),
        "openjev": ProviderCaps(
            base_url="http://localhost:8000", model="diffusiongemma-26b-a4b"
        ),
        "laya": ProviderCaps(
            base_url="http://localhost:8000",
            model="laya",
            max_choice_options=24,
            max_state_chars=2000
        )
    };
}


impl caps_for(provider: str) -> ProviderCaps {
    table = providers();
    if provider not in table {
        raise ConfigurationError(
            f"unknown System One provider {provider!r}; known: {sorted(table.keys())}"
        );
    }
    return table[provider];
}


impl resolve_model_name(name: str) -> tuple[str, str] {
    rest = name[len(SYSTEMONE_PREFIX):] if name.startswith(SYSTEMONE_PREFIX) else name;
    rest = rest.strip();
    if "/" in rest {
        (provider, model) = rest.split("/", 1);
        return (provider.strip() or DEFAULT_PROVIDER, model.strip());
    }
    if rest in providers() {
        return (rest, "");
    }
    return (DEFAULT_PROVIDER, rest);
}


impl resolve_api_key(caps: ProviderCaps, explicit: str = "") -> str {
    import os;

    if explicit {
        return explicit;
    }
    for env in [caps.key_env, *caps.key_env_aliases] {
        if env and os.environ.get(env) {
            return os.environ[env];
        }
    }
    return "";
}


impl distribution(spec: SystemOneSpec, answers: dict[str, any]) -> dict[str, any] {
    out: dict[str, any] = {};
    for (qid, q) in spec.questions.items() {
        a = answers.get(qid);
        if not isinstance(a, dict) {
            continue;
        }
        if q.kind == NOUL {
            p = float(a.get("noul", 0.0));
            out[qid] = {"true": p, "false": 1.0 - p};
        } else {
            probs = a.get("probabilities");
            out[qid] = dict(probs) if isinstance(probs, dict) else {};
        }
    }
    return out;
}
