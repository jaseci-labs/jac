import re;
import from jaclang.compiler.c2jac.tags { TagTable, NodeTag }
import from jaclang.compiler.c2jac.c_common { UNSUPPORTED_STMT, UNSUPPORTED_EXPR }

glob _MARKER_RE = re.compile(
         r"(?:" + re.escape(UNSUPPORTED_EXPR) + r"|" + re.escape(UNSUPPORTED_STMT) + r")\((\d+)\)"
     ),
     _NOTE_PREFIX = "# c2jac: BEST-EFFORT — ";

def inject_tier_b_comments(jac_str: str, tags: TagTable) -> str {
    entries = tags.tier_b_entries();
    if not entries {
        return jac_str;
    }
    by_line = _reasons_by_line(entries);
    out: list[str] = [];
    for ln in jac_str.split("\n") {
        matches = list(_MARKER_RE.finditer(ln));
        if matches {
            reasons: list[str] = [];
            for m in matches {
                for r in by_line.get(int(m.group(1)), []) {
                    if r not in reasons {
                        reasons.append(r);
                    }
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
