import from .state { TuiState, AcItem, EditorState, AcKind }
import from .commands { slash_ac_catalog }

def fuzzy_score(query: str, text: str) -> int {
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

obj ScoredEntry {
    has value: str = "",
        label: str = "",
        description: str = "",
        score: int = 0;
}

def _sort_entries_by_score(entries: list[ScoredEntry]) -> list[AcItem] {
    n = len(entries);
    i: int = 1;
    while i < n {
        cur = entries[i];
        j: int = i - 1;
        while j >= 0 {
            if entries[j].score <= cur.score {
                break;
            }
            entries[j + 1] = entries[j];
            j = j - 1;
        }
        entries[j + 1] = cur;
        i = i + 1;
    }

    result: list[AcItem] = [];
    k: int = 0;
    while k < n {
        entry = entries[k];
        result.append(
            AcItem(value=entry.value, label=entry.label, description=entry.description)
        );
        k = k + 1;
    }
    return result;
}

obj AutocompleteTrigger {
    has kind: AcKind = AcKind.NONE,
        prefix: str = "",
        query: str = "";
}

def _extract_trigger(ed: EditorState) -> AutocompleteTrigger {
    if len(ed.lines) == 0 {
        return AutocompleteTrigger();
    }

    cur_line = ed.lines[ed.cursor_line];
    before = cur_line[:ed.cursor_col];
    blen = len(before);

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
            return AutocompleteTrigger(
                kind=AcKind.SLASH, prefix=before, query=before[1:]
            );
        }
        return AutocompleteTrigger();
    }

    j: int = ed.cursor_col - 1;
    while j >= 0 {
        c = cur_line[j];
        if c == "@" {
            if j == 0 or cur_line[j - 1] == " " or cur_line[j - 1] == "\t" {
                prefix = before[j:];
                return AutocompleteTrigger(
                    kind=AcKind.AT_FILE, prefix=prefix, query=prefix[1:]
                );
            }
            break;
        }
        if c == " " or c == "\t" {
            break;
        }
        j = j - 1;
    }

    return AutocompleteTrigger();
}

def _slash_items(query: str, state: TuiState) -> list[AcItem] {
    catalog = slash_ac_catalog(state);
    entries: list[ScoredEntry] = [];

    i: int = 0;
    n = len(catalog);
    while i < n {
        item = catalog[i];
        cmd = item.value;
        desc = item.description;
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
            entries.append(
                ScoredEntry(value=cmd, label=cmd, description=desc, score=s)
            );
        }
        i = i + 1;
    }

    if len(query) == 0 {
        items: list[AcItem] = [];
        j: int = 0;
        while j < len(entries) {
            e = entries[j];
            items.append(
                AcItem(value=e.value, label=e.label, description=e.description)
            );
            j = j + 1;
        }
        return items;
    }
    return _sort_entries_by_score(entries);
}

def _file_items(state: TuiState, query: str) -> list[AcItem] {
    n = len(state.files);
    limit: int = n;
    if limit > 300 {
        limit = 300;
    }

    entries: list[ScoredEntry] = [];

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
            entries.append(
                ScoredEntry(value=path, label=base, description=path, score=s)
            );
        }
        i = i + 1;
    }

    if len(query) == 0 {
        items: list[AcItem] = [];
        j: int = 0;
        while j < len(entries) and j < 20 {
            e = entries[j];
            items.append(
                AcItem(value=e.value, label=e.label, description=e.description)
            );
            j = j + 1;
        }
        return items;
    }

    all_sorted = _sort_entries_by_score(entries);
    result: list[AcItem] = [];
    j: int = 0;
    while j < len(all_sorted) and j < 20 {
        result.append(all_sorted[j]);
        j = j + 1;
    }
    return result;
}

def ac_update(state: TuiState) {
    trigger = _extract_trigger(state.editor);

    if trigger.kind == AcKind.NONE {
        state.ac.dismiss();
        return;
    }

    items: list[AcItem] = [];
    if trigger.kind == AcKind.SLASH {
        items = _slash_items(trigger.query, state);
    } else {
        items = _file_items(state, trigger.query);
    }

    if len(items) == 0 {
        state.ac.dismiss();
        return;
    }

    same_kind = state.ac.active and state.ac.kind == trigger.kind;
    state.ac.active = True;
    state.ac.kind = trigger.kind;
    state.ac.prefix = trigger.prefix;
    state.ac.query = trigger.query;
    state.ac.items = items;
    if not same_kind {
        state.ac.selected_idx = 0;
    }
    if state.ac.selected_idx >= len(items) {
        state.ac.selected_idx = 0;
    }
}

def ac_apply(state: TuiState) {
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
    if state.ac.kind == AcKind.SLASH {
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
