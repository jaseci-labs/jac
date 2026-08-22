import os;
import from difflib { get_close_matches }

impl validate_against_schema(
    raw: dict[str, any] | None, options: dict[str, any], section: str
) -> list[str] {
    findings: list[str] = [];
    if not isinstance(raw, dict)
        or not raw
        or not isinstance(options, dict)
        or not options {
        return findings;
    }
    _walk_schema(raw, options, section, findings);
    return findings;
}

impl _walk_schema(
    table: dict[str, any], options: dict[str, any], path: str, findings: list[str]
) -> None {
    for (key, value) in table.items() {
        key_s = str(key);
        if key_s not in options {
            findings.append(
                _unknown_key_message(path, key_s, [str(k) for k in options.keys()])
            );
            continue;
        }
        spec = options.get(key_s);
        if not isinstance(spec, dict) or not isinstance(value, dict) {
            continue;
        }
        nested = spec.get("nested");
        if isinstance(nested, dict) {
            _walk_schema(value, nested, f"{path}.{key_s}", findings);
            continue;
        }
        nested_each = spec.get("nested_each");
        if isinstance(nested_each, dict) {
            for (child_key, child_val) in value.items() {
                if isinstance(child_val, dict) {
                    _walk_schema(
                        child_val, nested_each, f"{path}.{key_s}.{child_key}", findings
                    );
                }
            }
        }
    }
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
    import from jaclang.cli.console { console }
    for msg in findings {
        console.warning(msg);
    }
}
