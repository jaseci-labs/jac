impl DiagnosticInfo.format_message(**kwargs: object) -> str {
    filled = _fill_template(self.message_template, kwargs);
    if filled is None {
        return f"{self.message_template} (missing key)";
    }
    return filled;
}

impl DiagnosticInfo.format_help(**kwargs: object) -> (str | None) {
    if self.help_text is None {
        return None;
    }
    filled = _fill_template(self.help_text, kwargs);
    if filled is None {
        return self.help_text;
    }
    return filled;
}

impl _placeholder_name(text: str) -> bool {
    if not text {
        return False;
    }
    for ch in text {
        if not (ch.isalnum() or ch == "_") {
            return False;
        }
    }
    return True;
}

impl _fill_template(template: str, kwargs: dict[str, object]) -> (str | None) {
    out: list[str] = [];
    i = 0;
    n = len(template);
    while i < n {
        ch = template[i];
        if (ch == "{" or ch == "}") and i + 1 < n and template[i + 1] == ch {
            out.append(ch);
            i += 2;
            continue;
        }
        if ch == "{" {
            close = template.find("}", i + 1);
            if close > i and _placeholder_name(template[i + 1:close]) {
                key = template[i + 1:close];
                if key not in kwargs {
                    return None;
                }
                out.append(str(kwargs[key]));
                i = close + 1;
                continue;
            }
        }
        out.append(ch);
        i += 1;
    }
    return "".join(out);
}

impl _reg(
    code: str,
    severity: Severity,
    category: Category,
    template: str,
    help_text: str | None = None,
    blocks_codegen: bool = False
) -> DiagnosticInfo {
    sitting = DIAGNOSTICS.get(code);
    if sitting is not None {
        raise ValueError(
            f"diagnostic code {code} is claimed twice. It is already "
            f"registered as {sitting.severity.value}/{sitting.category.value} "
            f"'{sitting.message_template}' and is registered again as "
            f"{severity.value}/{category.value} '{template}'. A code names "
            "exactly one diagnostic: the second registration would shadow "
            "the first everywhere it is referenced, and the native link "
            "refuses this module on the duplicate symbol. Give the later "
            "claimant a code of its own and move its pins."
        );
    }
    info = DiagnosticInfo(
        code=code,
        severity=severity,
        category=category,
        message_template=template,
        help_text=help_text,
        url_slug=code.lower(),
        blocks_codegen=blocks_codegen
    );
    DIAGNOSTICS[code] = info;
    return info;
}

impl _err(
    code: str,
    cat: Category,
    tmpl: str,
    help: str | None = None,
    blocks_codegen: bool = False
) -> DiagnosticInfo {
    return _reg(code, Severity.ERROR, cat, tmpl, help, blocks_codegen);
}

impl _warn(
    code: str, cat: Category, tmpl: str, help: str | None = None
) -> DiagnosticInfo {
    return _reg(code, Severity.WARNING, cat, tmpl, help);
}
