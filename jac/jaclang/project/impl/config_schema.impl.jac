import os;
import sys;
import from difflib { get_close_matches }

impl TableRule.accepts(value: any) -> bool {
    if self.kind == "any" {
        return True;
    }
    if value is None {
        return self.optional;
    }
    if self.kind == "bool" {
        return isinstance(value, bool);
    }
    if isinstance(value, bool) {
        return False;
    }
    if self.kind == "int" {
        return isinstance(value, int);
    }
    if self.kind == "float" {
        return isinstance(value, (int, float));
    }
    if self.kind == "str" {
        return isinstance(value, str);
    }
    if self.kind == "list" {
        return isinstance(value, list);
    }
    return isinstance(value, dict);
}

impl TableProblem.describe -> str {
    if self.known is not None {
        head = f"[{self.section}] has no key {self.key!r}";
        matches = get_close_matches(self.key, self.known, n=1, cutoff=0.6);
        if matches {
            return f"{head}; did you mean {matches[0]!r}?";
        }
        listed = ", ".join(self.known);
        return f"{head}; its keys are {listed}";
    }
    if self.key {
        return f"[{self.section}] {self.key} {self.detail}";
    }
    return f"[{self.section}] {self.detail}";
}

impl rules_from_record(record: object) -> dict[str, TableRule] {
    owner = record if isinstance(record, `type) else type(record);
    return {
        f.name: rule_from_type(f.`type, owner, f"{owner.__name__}.{f.name}")
        for f in fields(record)
    };
}

impl rule_from_type(annotation: any, owner: object, label: str) -> TableRule {
    text = _type_text(annotation);
    parts = _split_top(text, "|");
    if len(parts) == 1 and text.startswith("(") and text.endswith(")") {
        return rule_from_type(text[1:-1], owner, label);
    }
    choices = [
        part
        for part in parts
        if part != "None"
    ];
    if len(choices) != 1 {
        raise TypeError(f"{label}: jac.toml has no form for the type {text!r}");
    }
    rule = _named_rule(choices[0], owner, label);
    rule.optional = len(choices) < len(parts);
    return rule;
}

impl _type_text(annotation: any) -> str {
    if isinstance(annotation, str) {
        return annotation.strip();
    }
    if isinstance(annotation, `type) {
        return annotation.__name__;
    }
    return str(annotation).strip();
}

impl _split_top(text: str, sep: str) -> list[str] {
    parts: list[str] = [];
    depth = 0;
    start = 0;
    for (index, char) in enumerate(text) {
        if char in "[(" {
            depth += 1;
        } elif char in "])" {
            depth -= 1;
        } elif char == sep and depth == 0 {
            parts.append(text[start:index].strip());
            start = index + 1;
        }
    }
    parts.append(text[start:].strip());
    return parts;
}

impl _named_rule(text: str, owner: object, label: str) -> TableRule {
    if text in SCALAR_KINDS {
        return TableRule(kind=SCALAR_KINDS[text]);
    }
    if "[" in text and text.endswith("]") {
        at = text.index("[");
        outer = text[:at].strip();
        args = _split_top(text[at + 1:-1], ",");
        if outer == "list" and len(args) == 1 {
            return TableRule(kind="list", item=rule_from_type(args[0], owner, label));
        }
        if outer == "dict" and len(args) == 2 and args[0] == "str" {
            return TableRule(kind="dict", item=rule_from_type(args[1], owner, label));
        }
    }
    module = sys.modules.get(owner.__module__);
    found = getattr(module, text, None) if module is not None else None;
    if isinstance(found, `type) and is_record(found) {
        return TableRule(kind="table", keys=rules_from_record(found));
    }
    raise TypeError(f"{label}: jac.toml has no form for the type {text!r}");
}

impl rules_from_schema(options: dict[str, any]) -> dict[str, TableRule] {
    return {str(name): _schema_rule(spec) for (name, spec) in options.items()};
}

impl _schema_rule(spec: any) -> TableRule {
    if not isinstance(spec, dict) {
        return TableRule(kind="any");
    }
    nested = spec.get("nested");
    if isinstance(nested, dict) {
        return TableRule(kind="table", keys=rules_from_schema(nested));
    }
    nested_each = spec.get("nested_each");
    if isinstance(nested_each, dict) {
        return TableRule(
            kind="dict",
            item=TableRule(kind="table", keys=rules_from_schema(nested_each))
        );
    }
    kind = SCHEMA_KINDS.get(str(spec.get("type", "")), "any");
    if kind in ("list", "dict") {
        return TableRule(kind=kind, item=TableRule(kind="any"));
    }
    return TableRule(kind=kind);
}

impl check_table(
    table: dict[str, any],
    rules: dict[str, TableRule],
    section: str,
    moved: dict[str, str],
    types: bool = True
) -> list[TableProblem] {
    problems: list[TableProblem] = [];
    _walk_table(table, rules, section, moved, types, problems);
    return problems;
}

impl _walk_table(
    table: dict[str, any],
    rules: dict[str, TableRule],
    section: str,
    moved: dict[str, str],
    types: bool,
    problems: list[TableProblem]
) -> None {
    for (key, raw) in table.items() {
        name = str(key);
        rule = rules.get(name);
        if rule is not None {
            _check_value(rule, raw, section, name, types, problems);
        } elif name in moved {
            problems.append(
                TableProblem(
                    section=section, key=name, detail=f"has moved to {moved[name]}"
                )
            );
        } else {
            problems.append(TableProblem(section=section, key=name, known=list(rules)));
        }
    }
}

impl _check_value(
    rule: TableRule,
    raw: any,
    section: str,
    key: str,
    types: bool,
    problems: list[TableProblem]
) -> None {
    path = f"{section}.{key}";
    if not rule.accepts(raw) {
        if types and rule.kind in ("table", "dict") {
            problems.append(TableProblem(section=path, detail="must be a table"));
        } elif types {
            problems.append(
                TableProblem(section=section, key=key, detail=_expects(rule, raw))
            );
        }
        return;
    }
    keys = rule.keys;
    item = rule.item;
    if raw is None {
        return;
    }
    if keys is not None {
        _walk_table(raw, keys, path, {}, types, problems);
    } elif item is None or item.kind == "any" {
        return;
    } elif rule.kind == "dict" {
        for (child, value) in raw.items() {
            _check_value(item, value, path, str(child), types, problems);
        }
    } elif types and not all(item.accepts(value) for value in raw) {
        problems.append(
            TableProblem(section=section, key=key, detail=_expects(rule, raw))
        );
    } else {
        for value in raw {
            _check_value(item, value, section, key, types, problems);
        }
    }
}

impl _expects(rule: TableRule, raw: any) -> str {
    item = rule.item;
    if item is not None {
        return f"must be a list of {KIND_WORDS.get(item.kind, ('', 'tables'))[1]}, got {raw!r}";
    }
    return f"must be {KIND_WORDS[rule.kind][0]}, got {raw!r}";
}

impl validate_against_schema(
    raw: dict[str, any] | None, options: dict[str, any], section: str
) -> list[str] {
    if not isinstance(raw, dict)
        or not raw
        or not isinstance(options, dict)
        or not options {
        return [];
    }
    return [
        _unknown_key_message(problem.section, problem.key, problem.known or [])
        for problem in check_table(raw, rules_from_schema(options), section, {}, False)
    ];
}

impl _unknown_key_message(path: str, key: str, known: list[str]) -> str {
    matches = get_close_matches(key, known, n=1, cutoff=0.6);
    hint = f"; did you mean '{matches[0]}'?" if matches else ".";
    return (
        f"jac.toml [{path}] has unknown key '{key}'{hint} "
        "Unknown keys are ignored, so defaults apply instead."
    );
}

impl schema_strict_enabled(strict_env: str) -> bool {
    if not strict_env {
        return False;
    }
    return os.environ.get(strict_env, "").strip().lower() in ("1", "true", "yes", "on");
}

impl report_schema_findings(
    findings: list[str], section: str, strict_env: str = ""
) -> None {
    if not findings {
        return;
    }
    if schema_strict_enabled(strict_env) {
        raise ValueError(
            f"Unknown [{section}] keys in jac.toml ({strict_env} is set):\n"
                + "\n".join(findings)
        );
    }

    for msg in findings {
        console.warning(msg);
    }
}
