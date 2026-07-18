import from .state { TuiState, AcKind }
import from .editor { EditorState }
import from .commands { slash_ac_catalog }
import from .select_list { SelectItem }

glob FUZZY_NO_MATCH: int = -9999;

glob _CONSEC_BONUS: int = 5,
     _GAP_PENALTY: int = 2,
     _BOUNDARY_BONUS: int = 10,
     _EXACT_BONUS: int = 100,
     _PATH_FALLBACK_PENALTY: int = 20,
     _FILE_SCAN_CAP: int = 300,
     _MAX_AC_RESULTS: int = 20;

glob _WORD_BOUNDARY_CHARS: str = "/-_. ";

def fuzzy_score(query: str, text: str) -> int {
    qn = len(query);
    tn = len(text);
    if qn == 0 {
        return 0;
    }
    if qn > tn {
        return FUZZY_NO_MATCH;
    }

    ql = query.lower();
    tl = text.lower();

    qi: int = 0;
    score: int = 0;
    last_match: int = -1;
    consec: int = 0;
    for i in range(tn) {
        if qi >= qn {
            break;
        }
        if tl[i] != ql[qi] {
            continue;
        }
        if last_match == i - 1 {
            consec += 1;
            score -= consec * _CONSEC_BONUS;
        } else {
            consec = 0;
            if last_match >= 0 {
                score += (i - last_match - 1) * _GAP_PENALTY;
            }
        }
        if i == 0 or tl[i - 1] in _WORD_BOUNDARY_CHARS {
            score -= _BOUNDARY_BONUS;
        }
        last_match = i;
        qi += 1;
    }

    if qi < qn {
        return FUZZY_NO_MATCH;
    }
    if ql == tl {
        score -= _EXACT_BONUS;
    }
    return score;
}

obj _ScoredItem {
    has item: SelectItem = SelectItem(),
        score: int = 0;
}

def _sort_entries_by_score(entries: list[_ScoredItem]) -> list[SelectItem] {
    for i in range(1, len(entries)) {
        cur = entries[i];
        j: int = i - 1;
        while j >= 0 and entries[j].score > cur.score {
            entries[j + 1] = entries[j];
            j -= 1;
        }
        entries[j + 1] = cur;
    }
    return [e.item for e in entries];
}

obj AutocompleteTrigger {
    has kind: AcKind = AcKind.NONE,
        prefix: str = "",
        query: str = "";
}

def _extract_trigger(ed: EditorState) -> AutocompleteTrigger {
    if not ed.lines {
        return AutocompleteTrigger();
    }

    cur_line = ed.lines[ed.cursor_line];
    before = cur_line[:ed.cursor_col];

    if ed.cursor_line == 0 and before.startswith("/") {
        if " " in before {
            return AutocompleteTrigger();
        }
        return AutocompleteTrigger(kind=AcKind.SLASH, prefix=before, query=before[1:]);
    }

    at = before.rfind("@");
    if at < 0 {
        return AutocompleteTrigger();
    }
    tail = before[at + 1:];
    if " " in tail or "\t" in tail {
        return AutocompleteTrigger();
    }
    if at > 0 and before[at - 1] not in " \t" {
        return AutocompleteTrigger();
    }
    prefix = before[at:];
    return AutocompleteTrigger(kind=AcKind.AT_FILE, prefix=prefix, query=prefix[1:]);
}

def _basename(path: str) -> str {
    slash_at = path.rfind("/");
    if slash_at < 0 {
        return path;
    }
    return path[slash_at + 1:];
}

def _slash_items(query: str, state: TuiState) -> list[SelectItem] {
    catalog = slash_ac_catalog(state);
    if not query {
        return catalog;
    }

    entries: list[_ScoredItem] = [];
    for item in catalog {
        cmd = item.value;
        score = fuzzy_score(query, cmd[1:]);
        if score != FUZZY_NO_MATCH {
            entries.append(_ScoredItem(item=item, score=score));
        }
    }
    return _sort_entries_by_score(entries);
}

def _file_items(state: TuiState, query: str) -> list[SelectItem] {
    files = state.files;
    limit = min(len(files), _FILE_SCAN_CAP);

    if not query {
        head = min(limit, _MAX_AC_RESULTS);
        return [
            SelectItem(value=path, label=_basename(path), description=path)
            for path in files[:head]
        ];
    }

    entries: list[_ScoredItem] = [];
    for path in files[:limit] {
        base = _basename(path);
        score = fuzzy_score(query, base);
        if score == FUZZY_NO_MATCH {
            score = fuzzy_score(query, path);
            if score != FUZZY_NO_MATCH {
                score += _PATH_FALLBACK_PENALTY;
            }
        }
        if score != FUZZY_NO_MATCH {
            entries.append(
                _ScoredItem(
                    item=SelectItem(value=path, label=base, description=path),
                    score=score
                )
            );
        }
    }

    ranked = _sort_entries_by_score(entries);
    keep = min(len(ranked), _MAX_AC_RESULTS);
    return ranked[:keep];
}

def ac_update(state: TuiState) {
    trigger = _extract_trigger(state.editor);
    if trigger.kind == AcKind.NONE {
        state.ac.dismiss();
        return;
    }

    items: list[SelectItem] = (
        _slash_items(trigger.query, state)
            if trigger.kind == AcKind.SLASH
            else _file_items(state, trigger.query)
    );
    if not items {
        state.ac.dismiss();
        return;
    }

    same_kind = state.ac.active and state.ac.kind == trigger.kind;
    state.ac.active = True;
    state.ac.kind = trigger.kind;
    state.ac.prefix = trigger.prefix;
    state.ac.query = trigger.query;
    state.ac.items = items;
    if not same_kind or state.ac.selected_idx >= len(items) {
        state.ac.selected_idx = 0;
    }
}

def ac_apply(state: TuiState) {
    if not state.ac.active or not state.ac.items {
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
    prefix_start = max(0, ed.cursor_col - prefix_len);
    before = cur_line[:prefix_start];
    after = cur_line[ed.cursor_col:];

    new_text: str = "";
    if state.ac.kind == AcKind.SLASH {
        new_text = item.value + " ";
    } else {
        val = item.value;
        suffix = "" if val.endswith("/") else " ";
        new_text = "@" + val + suffix;
    }

    ed.lines[ed.cursor_line] = before + new_text + after;
    ed.cursor_col = prefix_start + len(new_text);

    state.ac.dismiss();
    state.mark_layout_dirty();
}
