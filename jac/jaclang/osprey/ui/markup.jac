obj MarkupError {
    has path: str,
        message: str;
}


obj LowerResult {
    has graph_root: UiNode | None = None,
        errors: list[MarkupError] = [],
        generated_jac: str = "";
}


obj TagRegistry {
    has tags: dict[str, any] = {};
}


obj _MarkupElem {
    has tag: str = "",
        attrs: dict[str, str] = {},
        children: list[_MarkupElem] = [],
        path: str = "";
}


obj _MarkupMatch {
    has _groups: list[str | None] = [],
        _end: int = 0;

    def group(i: int) -> str | None;
    def end -> int;
}


def _is_name_start(c: str) -> bool;


def _is_name_cont(c: str) -> bool;


def _is_space(c: str) -> bool;


def _skip_ws(text: str, i: int) -> int;


def _read_name(text: str, i: int) -> tuple[str, int] | None;


def _match_tag_open(text: str, i: int) -> _MarkupMatch | None;


def _match_tag_close(text: str, i: int) -> _MarkupMatch | None;


def _match_attr(text: str, i: int) -> _MarkupMatch | None;


def _iter_attrs(text: str, end: int) -> list[_MarkupMatch];


def create_tag_registry -> TagRegistry;


def register_tag(registry: TagRegistry, tag: str, archetype: any);


def default_shell_registry -> TagRegistry;


def _allowed_props(tag: str) -> set[str];


def _parse_attrs(raw: str) -> dict[str, str];


def _parse_markup(source: str) -> (list[_MarkupElem], list[MarkupError]);


def _coerce_value(raw: str, field: str) -> any;


def _field_name(attr: str) -> str;


def _apply_attrs(
    ui_node: UiNode,
    tag: str,
    attrs: dict[str, str],
    path: str,
    errors: list[MarkupError],
);


def _ctor_args(tag: str, attrs: dict[str, str]) -> str;


def _instantiate_tracked(
    elem: _MarkupElem,
    registry: TagRegistry,
    errors: list[MarkupError],
    gen_lines: list[str],
    var_counter: list[int],
) -> (UiNode | None, str);


def lower_markup(
    source: str, registry: TagRegistry | None = None, print_generated: bool = False,
) -> LowerResult;


def print_generated(source: str, registry: TagRegistry | None = None) -> str;

impl _MarkupMatch.group(i: int) -> str | None {
    return self._groups[i - 1];
}

impl _MarkupMatch.end -> int {
    return self._end;
}


impl _is_name_start(c: str) -> bool {
    return c.isalpha() or c == "_";
}


impl _is_name_cont(c: str) -> bool {
    return c.isalnum() or c == "_";
}


impl _is_space(c: str) -> bool {
    return c == " " or c == "\t" or c == "\r" or c == "\n";
}


impl _skip_ws(text: str, i: int) -> int {
    n = len(text);
    while i < n and _is_space(text[i]) {
        i += 1;
    }
    return i;
}


impl _read_name(text: str, i: int) -> tuple[str, int] | None {
    n = len(text);
    if i >= n or not _is_name_start(text[i]) {
        return None;
    }
    start = i;
    i += 1;
    while i < n and _is_name_cont(text[i]) {
        i += 1;
    }
    return (text[start:i], i);
}


impl _match_tag_open(text: str, i: int) -> _MarkupMatch | None {
    n = len(text);
    if i >= n or text[i] != "<" {
        return None;
    }
    j = i + 1;
    j = _skip_ws(text, j);
    name_t = _read_name(text, j);
    if name_t is None {
        return None;
    }
    (name, j) = name_t;
    j = _skip_ws(text, j);
    attrs_start = j;
    while j < n and text[j] != ">" and text[j] != "/" {
        j += 1;
    }
    attrs = text[attrs_start:j];
    j = _skip_ws(text, j);
    slash: str | None = None;
    if j < n and text[j] == "/" {
        slash = "/";
        j += 1;
    }
    if j >= n or text[j] != ">" {
        return None;
    }
    j += 1;
    return _MarkupMatch(_groups=[name, attrs, slash], _end=j);
}


impl _match_tag_close(text: str, i: int) -> _MarkupMatch | None {
    n = len(text);
    if i + 1 >= n or text[i] != "<" or text[i + 1] != "/" {
        return None;
    }
    j = i + 2;
    j = _skip_ws(text, j);
    name_t = _read_name(text, j);
    if name_t is None {
        return None;
    }
    (name, j) = name_t;
    j = _skip_ws(text, j);
    if j >= n or text[j] != ">" {
        return None;
    }
    j += 1;
    return _MarkupMatch(_groups=[name], _end=j);
}


impl _match_attr(text: str, i: int) -> _MarkupMatch | None {
    n = len(text);
    name_t = _read_name(text, i);
    if name_t is None {
        return None;
    }
    (name, j) = name_t;
    j = _skip_ws(text, j);
    if j >= n or text[j] != "=" {
        return None;
    }
    j += 1;
    j = _skip_ws(text, j);
    if j >= n {
        return None;
    }
    quote = text[j];
    if quote != '"' and quote != "'" {
        return None;
    }
    j += 1;
    val_start = j;
    while j < n and text[j] != quote {
        j += 1;
    }
    if j >= n {
        return None;
    }
    val = text[val_start:j];
    j += 1;
    return _MarkupMatch(_groups=[name, val, None], _end=j);
}


impl _iter_attrs(text: str, end: int) -> list[_MarkupMatch] {
    out: list[_MarkupMatch] = [];
    i = 0;
    while i < end {
        i = _skip_ws(text, i);
        if i >= end {
            break;
        }
        m = _match_attr(text, i);
        if m is None {
            break;
        }
        out.append(m);
        i = m._end;
    }
    return out;
}


impl create_tag_registry -> TagRegistry {
    return TagRegistry();
}


impl register_tag(registry: TagRegistry, tag: str, archetype: any) {
    if not tag {
        raise ValueError("tag must not be empty");
    }
    registry.tags[tag] = archetype;
}


impl default_shell_registry -> TagRegistry {
    reg = create_tag_registry();
    register_tag(reg, "MainScreen", MainScreen);
    register_tag(reg, "Header", Header);
    register_tag(reg, "TranscriptView", TranscriptView);
    register_tag(reg, "Status", Status);
    register_tag(reg, "Prompt", Prompt);
    register_tag(reg, "ApprovalOverlay", ApprovalOverlay);
    return reg;
}


impl _allowed_props(tag: str) -> set[str] {
    base: set[str] = {"key"};
    if tag == "Header" {
        return base | {"title"};
    }
    if tag == "TranscriptView" {
        return base
            | {
                "scroll_offset",
                "follow_tail",
                "source_id",
                "observed_revision",
                "source",

            };
    }
    if tag == "Prompt" {
        return base | {"draft", "mode"};
    }
    if tag == "Status" {
        return base | {"phase", "source"};
    }
    if tag == "MainScreen" or tag == "ApprovalOverlay" {
        return base;
    }
    return base | {"value", "source", "title", "phase", "draft", "mode"};
}


impl _parse_attrs(raw: str) -> dict[str, str] {
    attrs: dict[str, str] = {};
    for m in _iter_attrs(raw, len(raw)) {
        raw_name = m.group(1);
        name: str = raw_name if raw_name is not None else "";
        val = m.group(2);
        if val is None {
            val = m.group(3);
        }
        if val is None {
            val = "";
        }
        attrs[name] = val;
    }
    return attrs;
}


impl _parse_markup(source: str) -> (list[_MarkupElem], list[MarkupError]) {
    errors: list[MarkupError] = [];
    roots: list[_MarkupElem] = [];
    stack: list[_MarkupElem] = [];
    i = 0;
    text = source;
    n = len(text);
    while i < n {
        while i < n and text[i] in " \t\r\n" {
            i += 1;
        }
        if i >= n {
            break;
        }
        if text[i] != "<" {
            next_lt = text.find("<", i);
            if next_lt < 0 {
                break;
            }
            i = next_lt;
            continue;
        }
        close_m = _match_tag_close(text, i);
        if close_m is not None {
            g1 = close_m.group(1);
            tag: str = g1 if g1 is not None else "";
            if not stack {
                errors.append(
                    MarkupError(path="/" + tag, message="unexpected close tag " + tag)
                );
            } else {
                top = stack[len(stack) - 1];
                if top.tag != tag {
                    errors.append(
                        MarkupError(
                            path=top.path, message="mismatched close tag " + tag,
                        )
                    );
                } else {
                    stack.pop();
                }
            }
            i = close_m.end();
            continue;
        }
        open_m = _match_tag_open(text, i);
        if open_m is None {
            errors.append(
                MarkupError(path="", message="malformed tag near index " + str(i))
            );
            break;
        }
        g1o = open_m.group(1);
        tag: str = g1o if g1o is not None else "";
        attr_raw = open_m.group(2);
        if attr_raw is None {
            attr_raw = "";
        }
        self_closing = open_m.group(3) is not None;
        attrs = _parse_attrs(attr_raw);
        parent_path = "";
        if stack {
            parent_path = stack[len(stack) - 1].path;
        }
        path = parent_path + "/" + tag;
        elem = _MarkupElem(tag=tag, attrs=attrs, path=path);
        if stack {
            stack[len(stack) - 1].children.append(elem);
        } else {
            roots.append(elem);
        }
        if not self_closing {
            stack.append(elem);
        }
        i = open_m.end();
    }
    if stack {
        errors.append(
            MarkupError(
                path=stack[len(stack) - 1].path,
                message="unclosed tag " + stack[len(stack) - 1].tag,
            )
        );
    }
    return (roots, errors);
}


impl _coerce_value(raw: str, field: str) -> any {
    if field in ("scroll_offset", "observed_revision") {
        try {
            return int(raw);
        } except Exception {
            return 0;
        }
    }
    if field == "follow_tail" {
        low = raw.lower();
        return low in ("1", "true", "yes");
    }
    if field == "value" {
        try {
            return float(raw);
        } except Exception {
            return 0.0;
        }
    }
    return raw;
}


impl _field_name(attr: str) -> str {
    if attr == "source" {
        return "source_id";
    }
    return attr;
}


impl _apply_attrs(
    ui_node: UiNode,
    tag: str,
    attrs: dict[str, str],
    path: str,
    errors: list[MarkupError],
) {
    allowed = _allowed_props(tag);
    for (name, raw) in attrs.items() {
        if name not in allowed {
            errors.append(
                MarkupError(
                    path=path, message="unknown property '" + name + "' on " + tag,
                )
            );
            continue;
        }
        field = _field_name(name);
        if not hasattr(ui_node, field) {
            errors.append(
                MarkupError(
                    path=path, message="unknown property '" + name + "' on " + tag,
                )
            );
            continue;
        }
        setattr(ui_node, field, _coerce_value(raw, field));
    }
}


impl _ctor_args(tag: str, attrs: dict[str, str]) -> str {
    key = attrs.get("key", "");
    parts: list[str] = ["key=" + repr(key)];
    for (name, raw) in sorted(attrs.items()) {
        if name == "key" {
            continue;
        }
        if name not in _allowed_props(tag) {
            continue;
        }
        field = _field_name(name);
        if field in ("scroll_offset", "observed_revision", "follow_tail", "value") {
            parts.append(field + "=" + str(_coerce_value(raw, field)));
        } else {
            parts.append(field + "=" + repr(raw));
        }
    }
    return ", ".join(parts);
}


impl _instantiate_tracked(
    elem: _MarkupElem,
    registry: TagRegistry,
    errors: list[MarkupError],
    gen_lines: list[str],
    var_counter: list[int],
) -> (UiNode | None, str) {
    if elem.tag not in registry.tags {
        errors.append(
            MarkupError(path=elem.path, message="unknown tag '" + elem.tag + "'",)
        );
        return (None, "");
    }
    archetype = registry.tags[elem.tag];
    key = elem.attrs.get("key", "");
    try {
        ui_node = archetype(key=key) as UiNode;
    } except Exception as exc {
        errors.append(
            MarkupError(
                path=elem.path,
                message="failed to construct " + elem.tag + ": " + str(exc),
            )
        );
        return (None, "");
    }
    _apply_attrs(ui_node, elem.tag, elem.attrs, elem.path, errors);

    var_counter[0] = var_counter[0] + 1;
    var_name = "n" + str(var_counter[0]);
    gen_lines.append(
        var_name + " = " + elem.tag + "(" + _ctor_args(elem.tag, elem.attrs) + ");"
    );

    for child in elem.children {
        (child_node, child_var) = _instantiate_tracked(
            child, registry, errors, gen_lines, var_counter
        );
        if child_node is None {
            continue;
        }
        if not isinstance(ui_node, UiContainer) {
            errors.append(
                MarkupError(
                    path=elem.path, message=elem.tag + " cannot contain children",
                )
            );
            continue;
        }
        append_child(ui_node, child_node);
        gen_lines.append("append_child(" + var_name + ", " + child_var + ");");
    }
    return (ui_node, var_name);
}


impl lower_markup(
    source: str, registry: TagRegistry | None = None, print_generated: bool = False,
) -> LowerResult {
    reg = registry;
    if reg is None {
        reg = default_shell_registry();
    }
    (roots, parse_errors) = _parse_markup(source);
    errors: list[MarkupError] = list(parse_errors);
    if not roots {
        if not errors {
            errors.append(MarkupError(path="", message="empty markup"));
        }
        return LowerResult(errors=errors);
    }
    if len(roots) > 1 {
        errors.append(
            MarkupError(path="", message="markup must have a single root element")
        );
        return LowerResult(errors=errors);
    }
    gen_lines: list[str] = [];
    counter: list[int] = [0];
    (graph_root, root_var) = _instantiate_tracked(
        roots[0], reg, errors, gen_lines, counter
    );
    if errors {
        return LowerResult(errors=errors, generated_jac="\n".join(gen_lines));
    }
    generated: str = "\n".join(gen_lines);
    if print_generated and root_var {
        generated = generated + "\n# root: " + root_var;
    }
    return LowerResult(graph_root=graph_root, errors=[], generated_jac=generated,);
}


impl print_generated(source: str, registry: TagRegistry | None = None) -> str {
    result = lower_markup(source, registry, print_generated=True);
    if result.errors {
        msgs = [e.message for e in result.errors];
        raise ValueError("markup errors: " + "; ".join(msgs));
    }
    return result.generated_jac;
}
