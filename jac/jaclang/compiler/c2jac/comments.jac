"""P3 post-format Tier-B comment injection (derived from the TagTable).

Inline comments cannot ride the AST: CPython drops comments at the tokenizer
before the AST exists, and Jac's own comment handling is token/source-based —
a synthetically built c2jac module has no `src_terminals` for the formatter's
CommentInjectionPass to anchor against. So Tier-B annotations are injected as a
*post-format text pass* over the already-formatted Jac (§7, resolving §9.2a).

The authoritative artifact is still the sidecar `*.c2jac.report.json`; these
comments are a convenience derived from the same TagTable. Two outputs:

- A compact **header block** listing every Tier-B site by C-source line + reason,
  pointing at the sidecar. This is the only visibility the *faithful* Tier-B
  sites get (cast-elision, C-for desugaring, comma-expression) — their emitted
  Jac is deliberately indistinguishable from Tier-A and carries no inline marker.
- An **inline** `# c2jac: BEST-EFFORT — <reason>` on each surrogate-marker line
  (`__c2jac_unsupported__(<c_line>)` / `__c2jac_unsupported_expr__(<c_line>)`).
  The surrogate emits its C-source line as the call argument; matching on that
  line is the §9.2a coordinate-space resolution (anchor in C-source space, which
  both the tag's `c_line` and the emitted marker share).

Entry point: inject_tier_b_comments(jac_str, tags, filename) -> str
"""

import re;
import from jaclang.compiler.c2jac.tags { TagTable, NodeTag }

# Matches both __c2jac_unsupported__(N) and __c2jac_unsupported_expr__(N); the
# captured group is the C-source line the surrogate carries as its anchor.
glob _MARKER_RE = re.compile(r"__c2jac_unsupported(?:_expr)?__\((\d+)\)"),
     _NOTE_PREFIX = "# c2jac: BEST-EFFORT — ";

def inject_tier_b_comments(jac_str: str, tags: TagTable, filename: str = "") -> str {
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
    return _build_header(by_line, filename) + "\n".join(out);
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
            by_line[nt.c_line] = ["best-effort translation — see sidecar"];
        }
    }
    return by_line;
}

def _report_name(filename: str) -> str {
    if not filename {
        return "the .c2jac.report.json sidecar";
    }
    base = filename.rsplit("/", 1)[-1];
    stem = base.rsplit(".", 1)[0] if "." in base else base;
    return f"{stem}.c2jac.report.json";
}

def _build_header(by_line: dict[int, list[str]], filename: str) -> str {
    # One row per (C line, reason), counting distinct explained sites.
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
        f"# c2jac: {n} best-effort (Tier-B) {sites} — authoritative detail in {_report_name(
            filename
        )}"
    ];
    for (c_line, r) in rows {
        hdr.append(f"#   L{c_line}  {r}");
    }
    return "\n".join(hdr) + "\n";
}
