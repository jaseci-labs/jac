import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.c2jac.tags { TagTable, NodeTag }
import from jaclang.compiler.c2jac.c_common { UNSUPPORTED_STMT, UNSUPPORTED_EXPR }

glob _NOTE_PREFIX = "# c2jac: BEST-EFFORT — ",
     _SURROGATE_NAMES = frozenset([UNSUPPORTED_STMT, UNSUPPORTED_EXPR]);

def inject_tier_b_comments(jac_str: str, tags: TagTable, uni_mod: uni.Module) -> str {
    entries = tags.tier_b_entries();
    if not entries {
        return jac_str;
    }
    by_line = _reasons_by_line(entries);
    surr_lines = _surrogate_output_lines(uni_mod, jac_str);
    out: list[str] = [];
    for (i, ln) in enumerate(jac_str.split("\n"), start=1) {
        c_line = surr_lines.get(i);
        if c_line is not None {
            reasons: list[str] = [];
            for r in by_line.get(c_line, []) {
                if r not in reasons {
                    reasons.append(r);
                }
            }
            note = "; ".join(reasons) if reasons else "unsupported C construct";
            out.append(f"{ln}  {_NOTE_PREFIX}{note}");
        } else {
            out.append(ln);
        }
    }
    return _build_header(by_line) + "\n".join(out);
}

def _surrogate_output_lines(uni_mod: uni.Module, jac_str: str) -> dict[int, int] {
    keys: list[tuple[str, int]] = [];
    for nd in uni_mod.flatten() {
        if not isinstance(nd, uni.FuncCall) {
            continue;
        }
        tgt = nd.target;
        if not isinstance(tgt, uni.Name) or tgt.value not in _SURROGATE_NAMES {
            continue;
        }
        c_ln = _surrogate_c_line(nd);
        keys.append((f"{tgt.value}({c_ln})", c_ln));
    }
    if not keys {
        return {};
    }
    out: dict[int, int] = {};
    for (i, ln) in enumerate(jac_str.split("\n"), start=1) {
        norm = _norm_scan(ln);
        for (key, c_ln) in keys {
            if key in norm {
                out[i] = c_ln;
            }
        }
    }
    return out;
}

def _norm_scan(s: str) -> str {
    return "".join(s.split());
}

def _surrogate_c_line(call: uni.FuncCall) -> int {
    if call.params and len(call.params) > 0 {
        p = call.params[0];
        if isinstance(p, uni.Int) {
            return p.lit_value;
        }
    }
    return call.loc.first_line if call.loc else 0;
}

def _reasons_by_line(entries: list[NodeTag]) -> dict[int, list[str]] {
    by_line: dict[int, list[str]] = {};
    for nt in entries {
        r = nt.reason.strip();
        if not r {
            continue;
        }
        bucket = by_line.setdefault(nt.c_line, []);
        if r not in bucket {
            bucket.append(r);
        }
    }
    return by_line;
}

def tier_b_site_count(tags: TagTable) -> int {
    entries = tags.tier_b_entries();
    if not entries {
        return 0;
    }
    by_line = _reasons_by_line(entries);
    return sum([len(reasons) for reasons in by_line.values()]);
}

def _build_header(by_line: dict[int, list[str]]) -> str {
    rows: list[tuple[int, str]] = [];
    for (c_line, reasons) in by_line.items() {
        for r in reasons {
            rows.append((c_line, r));
        }
    }
    rows.sort();
    n = len(rows);
    sites = "site" if n == 1 else "sites";
    hdr: list[str] = [
        f"# c2jac: {n} best-effort (Tier-B) {sites} — full list below; surrogate sites are also flagged inline"
    ];
    for (c_line, r) in rows {
        hdr.append(f"#   L{c_line}  {r}");
    }
    return "\n".join(hdr) + "\n";
}
