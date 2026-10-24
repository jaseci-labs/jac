impl _lowering_kind(name: str) -> NativeLoweringKind {
    if name == "callable" {
        return NativeLoweringKind.CALLABLE;
    }
    if name == "field" {
        return NativeLoweringKind.FIELD;
    }
    raise ValueError(f"{name!r} is not a valid NativeLoweringKind");
}

impl NativeLoweringIssue.record(module: ir.Module) {
    payload = json.dumps(
        [self.symbol, self.kind.value, self.source, self.code, self.detail],
        ensure_ascii=True
    ).encode(
        "utf-8"
    ).hex();
    module.add_named_metadata(LOWERING_METADATA, [payload]);
}

impl _skip_blanks(text: str, at: int) -> int {
    while at < len(text) and text[at] in _BLANKS {
        at += 1;
    }
    return at;
}

impl _node_references(operands: str) -> list[str] {
    found: list[str] = [];
    at = 0;
    while at < len(operands) {
        if operands[at] == "!" {
            stop = at + 1;
            while stop < len(operands) and operands[stop] in _DEC_DIGITS {
                stop += 1;
            }
            if stop > at + 1 {
                found.append(operands[at + 1:stop]);
            }
            at = stop;
        } else {
            at += 1;
        }
    }
    return found;
}

impl _lowering_roots(llvm_ir_text: str) -> list[str] {
    roots: list[str] = [];
    marker = "!" + LOWERING_METADATA;
    at = llvm_ir_text.find(marker);
    while at >= 0 {
        after = at + len(marker);
        if at == 0 or llvm_ir_text[at - 1] == "\n" {
            cursor = after;
            while cursor < len(llvm_ir_text)
                and (llvm_ir_text[cursor] in _BLANKS or llvm_ir_text[cursor] == "\n") {
                cursor += 1;
            }
            if llvm_ir_text[cursor:cursor + 1] == "=" {
                cursor += 1;
                while cursor < len(llvm_ir_text)
                    and (
                        llvm_ir_text[cursor] in _BLANKS or llvm_ir_text[cursor] == "\n"
                    ) {
                    cursor += 1;
                }
                if llvm_ir_text[cursor:cursor + 2] == "!{" {
                    close = llvm_ir_text.find("}", cursor + 2);
                    if close >= 0 {
                        roots.append(llvm_ir_text[cursor + 2:close]);
                    }
                }
            }
        }
        at = llvm_ir_text.find(marker, after);
    }
    return roots;
}

impl _hex_nodes(llvm_ir_text: str) -> dict[str, str] {
    nodes: dict[str, str] = {};
    for line in llvm_ir_text.split("\n") {
        if len(line) < 2 or line[0] != "!" or line[1] not in _DEC_DIGITS {
            continue;
        }
        stop = 1;
        while stop < len(line) and line[stop] in _DEC_DIGITS {
            stop += 1;
        }
        number = line[1:stop];
        cursor = _skip_blanks(line, stop);
        if line[cursor:cursor + 1] != "=" {
            continue;
        }
        cursor = _skip_blanks(line, cursor + 1);
        if line[cursor:cursor + 2] != "!{" {
            continue;
        }
        cursor = _skip_blanks(line, cursor + 2);
        if line[cursor:cursor + 2] != '!"' {
            continue;
        }
        start = cursor + 2;
        cursor = start;
        while cursor < len(line) and line[cursor] in _HEX_DIGITS {
            cursor += 1;
        }
        if cursor == start or line[cursor:cursor + 1] != '"' {
            continue;
        }
        payload = line[start:cursor];
        cursor = _skip_blanks(line, cursor + 1);
        if line[cursor:cursor + 1] != "}" {
            continue;
        }
        nodes[number] = payload;
    }
    return nodes;
}

impl native_lowering_issues(llvm_ir_text: str) -> list[NativeLoweringIssue] {
    roots = _lowering_roots(llvm_ir_text);
    if not roots {
        return [];
    }
    definitions = _hex_nodes(llvm_ir_text);
    issues: list[NativeLoweringIssue] = [];
    seen: set[str] = set();
    for references in roots {
        for key in _node_references(references) {
            payload = definitions[key];
            if payload in seen {
                continue;
            }
            seen.add(payload);
            values = json.loads(bytes.fromhex(payload).decode("utf-8"));
            fields: list[str] = [];
            if isinstance(values, `list) {
                for value in values {
                    if isinstance(value, str) {
                        fields.append(value);
                    }
                }
            }
            if not isinstance(values, `list) or len(values) != 5 or len(fields) != 5 {
                raise ValueError("Invalid native lowering metadata");
            }
            issues.append(
                NativeLoweringIssue(
                    symbol=fields[0],
                    kind=_lowering_kind(fields[1]),
                    source=fields[2],
                    code=fields[3],
                    detail=fields[4]
                )
            );
        }
    }
    return issues;
}

impl NativeFallbacks.require {
    if not self.symbols {
        return;
    }
    details = "\n".join(issue.detail for issue in self.issues);
    raise ValueError(
        "Native-only compilation cannot use Python fallback or erased fields: "
            + ", ".join(self.symbols)
            + ("\n" + details if details else "")
    );
}

impl native_fallbacks(
    issues: list[NativeLoweringIssue], demoted_definitions: list[str]
) -> NativeFallbacks {
    return NativeFallbacks(
        symbols=sorted(set(demoted_definitions) | {issue.symbol for issue in issues}),
        issues=list(issues)
    );
}

impl _defined_symbol(line: str) -> str {
    if not line.startswith("define") {
        return "";
    }
    at = line.find("@");
    if at < 0 {
        return "";
    }
    if line[at + 1:at + 2] == '"' {
        close = line.find('"', at + 2);
        if close < 0 or line[close + 1:close + 2] != "(" {
            return "";
        }
        return line[at + 2:close];
    }
    stop = line.find("(", at + 1);
    return line[at + 1:stop] if stop > at + 1 else "";
}

impl native_fallbacks_in_ir(llvm_ir_text: str) -> NativeFallbacks {
    demoted: list[str] = [];
    for line in llvm_ir_text.split("\n") {
        symbol = _defined_symbol(line);
        if symbol.endswith(DEMOTED_SUFFIX) {
            demoted.append(symbol.removesuffix(DEMOTED_SUFFIX));
        }
    }
    return native_fallbacks(native_lowering_issues(llvm_ir_text), demoted);
}
