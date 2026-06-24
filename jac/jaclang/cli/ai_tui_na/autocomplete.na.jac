"""Inline autocomplete: fuzzy engine, trigger detection, item builders, apply.

Triggers:
  "slash"   - line starts with / and no space yet  (e.g. /mo -> /model)
  "at_file" - last token before cursor starts with @ (e.g. @src -> @src/app.jac)

Port of pi packages/tui/src/fuzzy.ts (matchQuery) and autocomplete.ts logic.
"""

import from .state { TuiState, AcItem, EditorState }

# ── Slash commands available for inline completion ────────────────────────────
# Values are the full text inserted into the editor (with leading /).
glob _SC_VALUES: list[str] = [
         "/model",
         "/files",
         "/stop",
         "/clear",
         "/reset",
         "/quit"
     ],
     _SC_DESCS: list[str] = [
         "Switch the active model",
         "Insert a project file reference",
         "Stop the current turn",
         "Clear transcript and reset session",
         "Clear transcript and reset session",
         "Exit jac ai TUI"
     ];

# ── Fuzzy scoring (port of pi's fuzzy.ts matchQuery) ─────────────────────────
def fuzzy_score(query: str, text: str) -> int {
    # Returns -9999 on no match. Lower (more negative) score = better match.
    # Exact match: -100 bonus. Consecutive chars: -5 each. Word boundary: -10.
    # Gap between matched chars: +2 per skipped char.
    qn = len(query);
    tn = len(text);
    if qn == 0 {
        return 0;
    }
    if qn > tn {
        return -9999;
    }

    ql = query.lower();
    tl = text.lower();

    qi: int = 0;
    score: int = 0;
    last_match: int = -1;
    consec: int = 0;

    i: int = 0;
    while i < tn and qi < qn {
        if tl[i] == ql[qi] {
            if last_match == i - 1 {
                consec = consec + 1;
                score = score - consec * 5;
            } else {
                consec = 0;
                if last_match >= 0 {
                    score = score + (i - last_match - 1) * 2;
                }
            }
            # Word boundary bonus: start of text or after / - . _ space
            if i == 0 {
                score = score - 10;
            } elif tl[i - 1] == "/"
            or tl[i - 1] == "-"
            or tl[i - 1] == "_"
            or tl[i - 1] == "."
            or tl[i - 1] == " " {
                score = score - 10;
            }
            last_match = i;
            qi = qi + 1;
        }
        i = i + 1;
    }

    if qi < qn {
        return -9999;
    }

    if ql == tl {
        score = score - 100;
    }

    return score;
}

# ── Path helpers ──────────────────────────────────────────────────────────────
def _basename(path: str) -> str {
    n = len(path);
    i: int = n - 1;
    while i >= 0 {
        if path[i] == "/" {
            return path[i + 1:];
        }
        i = i - 1;
    }
    return path;
}

# ── Sort helpers (NA has no in-place list item assignment, use rebuild) ───────
def _sort_items_by_score(
    vals: list[str], labs: list[str], descs: list[str], scores: list[int]
) -> list[AcItem] {
    # Selection sort: extract minimum-score item each round, building result.
    rem_v = vals;
    rem_l = labs;
    rem_d = descs;
    rem_s = scores;
    result: list[AcItem] = [];

    while len(rem_s) > 0 {
        best: int = 0;
        j: int = 1;
        while j < len(rem_s) {
            if rem_s[j] < rem_s[best] {
                best = j;
            }
            j = j + 1;
        }
        result.append(
            AcItem(value=rem_v[best], label=rem_l[best], description=rem_d[best])
        );

        # Rebuild without picked index
        nv: list[str] = [];
        nl: list[str] = [];
        nd: list[str] = [];
        ns: list[int] = [];
        k: int = 0;
        while k < len(rem_s) {
            if k != best {
                nv.append(rem_v[k]);
                nl.append(rem_l[k]);
                nd.append(rem_d[k]);
                ns.append(rem_s[k]);
            }
            k = k + 1;
        }
        rem_v = nv;
        rem_l = nl;
        rem_d = nd;
        rem_s = ns;
    }
    return result;
}

# ── Trigger detection ─────────────────────────────────────────────────────────
def _extract_trigger(ed: EditorState) -> list[str] {
    # Returns [kind, prefix, query]. kind="" means no completion active.
    if len(ed.lines) == 0 {
        return ["", "", ""];
    }

    cur_line = ed.lines[ed.cursor_line];
    before = cur_line[:ed.cursor_col];
    blen = len(before);

    # Slash command: must be on line 0, starts with /, no space yet.
    if ed.cursor_line == 0 and blen > 0 and before[0] == "/" {
        j: int = 1;
        has_space: bool = False;
        while j < blen {
            if before[j] == " " {
                has_space = True;
                break;
            }
            j = j + 1;
        }
        if not has_space {
            return ["slash", before, before[1:]];
        }
        return ["", "", ""];
    }

    # @file: find the last @ token that starts at a word boundary.
    j: int = ed.cursor_col - 1;
    while j >= 0 {
        c = cur_line[j];
        if c == "@" {
            if j == 0 or cur_line[j - 1] == " " or cur_line[j - 1] == "\t" {
                prefix = before[j:];
                return ["at_file", prefix, prefix[1:]];
            }
            break;
        }
        if c == " " or c == "\t" {
            break;
        }
        j = j - 1;
    }

    return ["", "", ""];
}

# ── Item builders ─────────────────────────────────────────────────────────────
def _slash_items(query: str) -> list[AcItem] {
    vals: list[str] = [];
    labs: list[str] = [];
    descs_: list[str] = [];
    scores: list[int] = [];

    i: int = 0;
    n = len(_SC_VALUES);
    while i < n {
        cmd = _SC_VALUES[i];
        desc = _SC_DESCS[i];
        name = cmd[1:];
        s: int = 0;
        matched: bool = True;
        if len(query) > 0 {
            s = fuzzy_score(query, name);
            if s == -9999 {
                matched = False;
            }
        }
        if matched {
            vals.append(cmd);
            labs.append(cmd);
            descs_.append(desc);
            scores.append(s);
        }
        i = i + 1;
    }

    if len(query) == 0 {
        # No query: return in natural order
        items: list[AcItem] = [];
        j: int = 0;
        while j < len(vals) {
            items.append(AcItem(value=vals[j], label=vals[j], description=descs_[j]));
            j = j + 1;
        }
        return items;
    }
    return _sort_items_by_score(vals, labs, descs_, scores);
}

def _file_items(state: TuiState, query: str) -> list[AcItem] {
    n = len(state.files);
    limit: int = n;
    if limit > 300 {
        limit = 300;
    }

    vals: list[str] = [];
    labs: list[str] = [];
    descs_: list[str] = [];
    scores: list[int] = [];

    i: int = 0;
    while i < limit {
        path = state.files[i];
        base = _basename(path);
        s: int = 0;
        matched: bool = True;
        if len(query) > 0 {
            s = fuzzy_score(query, base);
            if s == -9999 {
                s = fuzzy_score(query, path);
                if s != -9999 {
                    s = s + 20;
                }
            }
            if s == -9999 {
                matched = False;
            }
        }
        if matched {
            vals.append(path);
            labs.append(base);
            descs_.append(path);
            scores.append(s);
        }
        i = i + 1;
    }

    if len(query) == 0 {
        # No query: return first 20 in order
        items: list[AcItem] = [];
        j: int = 0;
        while j < len(vals) and j < 20 {
            items.append(AcItem(value=vals[j], label=labs[j], description=descs_[j]));
            j = j + 1;
        }
        return items;
    }

    # Sort by score and return top 20
    all_sorted = _sort_items_by_score(vals, labs, descs_, scores);
    result: list[AcItem] = [];
    j: int = 0;
    while j < len(all_sorted) and j < 20 {
        result.append(all_sorted[j]);
        j = j + 1;
    }
    return result;
}

# ── Public API ────────────────────────────────────────────────────────────────
def ac_update(state: TuiState) {
    # Recompute AC state from current editor content. Call after every edit.
    trigger = _extract_trigger(state.editor);
    kind = trigger[0];
    prefix = trigger[1];
    query = trigger[2];

    if len(kind) == 0 {
        state.ac.dismiss();
        return;
    }

    items: list[AcItem] = [];
    if kind == "slash" {
        items = _slash_items(query);
    } else {
        items = _file_items(state, query);
    }

    if len(items) == 0 {
        state.ac.dismiss();
        return;
    }

    same_kind = state.ac.active and state.ac.kind == kind;
    state.ac.active = True;
    state.ac.kind = kind;
    state.ac.prefix = prefix;
    state.ac.query = query;
    state.ac.items = items;
    if not same_kind {
        state.ac.selected_idx = 0;
    }
    if state.ac.selected_idx >= len(items) {
        state.ac.selected_idx = 0;
    }
}

def ac_apply(state: TuiState) {
    # Replace the trigger prefix in the editor with the selected item's value.
    if not state.ac.active or len(state.ac.items) == 0 {
        return;
    }
    idx = state.ac.selected_idx;
    if idx < 0 or idx >= len(state.ac.items) {
        return;
    }
    item = state.ac.items[idx];
    ed = state.editor;
    cur_line = ed.lines[ed.cursor_line];
    prefix_len = len(state.ac.prefix);
    prefix_start = ed.cursor_col - prefix_len;
    if prefix_start < 0 {
        prefix_start = 0;
    }
    before = cur_line[:prefix_start];
    after = cur_line[ed.cursor_col:];

    new_text: str = "";
    if state.ac.kind == "slash" {
        new_text = item.value + " ";
    } else {
        val = item.value;
        if val.endswith("/") {
            new_text = "@" + val;
        } else {
            new_text = "@" + val + " ";
        }
    }

    new_line = before + new_text + after;
    new_lines: list[str] = [];
    i: int = 0;
    n = len(ed.lines);
    while i < n {
        if i == ed.cursor_line {
            new_lines.append(new_line);
        } else {
            new_lines.append(ed.lines[i]);
        }
        i = i + 1;
    }
    ed.lines = new_lines;
    ed.cursor_col = prefix_start + len(new_text);

    state.ac.dismiss();
    state.dirty = True;
}
