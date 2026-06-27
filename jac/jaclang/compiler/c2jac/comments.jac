"""Post-format Tier-B comment injection (derived from the TagTable).

Tier-B annotations are injected as a text pass over the already-formatted Jac:
CPython discards comments before the AST exists and Jac's CommentInjectionPass
requires src_terminals not present in a synthetically built module (§7, §9.2a).

Entry point: inject_tier_b_comments(jac_str, tags) -> str
"""

import re;
import from jaclang.compiler.c2jac.tags { TagTable, NodeTag }
import from jaclang.compiler.c2jac.c_common { UNSUPPORTED_STMT, UNSUPPORTED_EXPR }

# The surrogate names this matcher keys on are owned by c2jac.c_common (the
# emitter, mapper.impl/core.impl.jac, imports the same two globs). Building the
# regex from those constants — rather than re-typing the literal — keeps the
# matcher and the emitter on one source of truth: rename the sentinel in c_common
# and both move together. The _expr alternative comes first so the longer name
# wins. CI backstop: 'surrogate lines get an inline BEST-EFFORT note'.
glob _MARKER_RE = re.compile(
         r"(?:" + re.escape(UNSUPPORTED_EXPR) + r"|" + re.escape(UNSUPPORTED_STMT) + r")\((\d+)\)"
     ),
     _NOTE_PREFIX = "# c2jac: BEST-EFFORT — ";

def inject_tier_b_comments(jac_str: str, tags: TagTable) -> str {
    entries = tags.tier_b_entries();
    if not entries {
        # No best-effort sites — emit faithful Jac untouched (and no header).
        return jac_str;
    }
    by_line = _reasons_by_line(entries);
    out: list[str] = [];
    for ln in jac_str.split("\n") {
        m = _MARKER_RE.search(ln);
        if m is not None {
            c_line = int(m.group(1));
            reasons = by_line.get(c_line, []);
            note = "; ".join(reasons) if reasons else "unsupported C construct";
            # The formatted statement already ends with ';' — append inline.
            out.append(f"{ln}  {_NOTE_PREFIX}{note}");
        } else {
            out.append(ln);
        }
    }
    return _build_header(by_line) + "\n".join(out);
}

def _reasons_by_line(entries: list[NodeTag]) -> dict[int, list[str]] {
    # Dedupe explained reasons per C line. The boundary table default-tags some
    # container nodes Tier-B with an empty reason (a wrapper of an already-
    # explained child); those would otherwise emit blank `#   Ln  ` header rows
    # and trailing `; ` in the inline note. Keep distinct non-empty reasons; for
    # a line whose entries are ALL unexplained, fall back to one generic note so
    # the site still appears.
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
    for nt in entries {
        if nt.c_line not in by_line {
            by_line[nt.c_line] = ["best-effort translation"];
        }
    }
    return by_line;
}

def tier_b_site_count(tags: TagTable) -> int {
    # The authoritative count of best-effort sites: distinct (C line, reason)
    # rows as rendered in the header — NOT len(tier_b_entries()). The boundary
    # table default-tags container nodes Tier-B with an empty reason (e.g. a
    # wrapper sharing a C line with an already-explained child), which
    # _reasons_by_line collapses away. Reporting the raw entry count would
    # over-state the site total and contradict the inline header (§3 honest
    # report). Callers (the CLI warning) should use this so the user-facing
    # number matches the record in the output.
    entries = tags.tier_b_entries();
    if not entries {
        return 0;
    }
    by_line = _reasons_by_line(entries);
    return sum([len(reasons) for reasons in by_line.values()]);
}

def _build_header(by_line: dict[int, list[str]]) -> str {
    # One row per (C line, reason), counting distinct explained sites. The header
    # plus the inline per-site notes are the authoritative Tier-B record.
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
        f"# c2jac: {n} best-effort (Tier-B) {sites} — each is listed below and marked inline at its site"
    ];
    for (c_line, r) in rows {
        hdr.append(f"#   L{c_line}  {r}");
    }
    return "\n".join(hdr) + "\n";
}
