"""Autocomplete: fuzzy-ranked slash-command and @file suggestions.

Detects a trigger under the editor cursor (a `/command` on the first
line, or an `@path` token), ranks candidates with `fuzzy_score`, and
splices the accepted suggestion back into the editor line. Siblings
consume only `ac_update` / `ac_apply` (input.na.jac).
"""

import from .state { TuiState, AcKind }
import from .editor { EditorState }
import from .commands { slash_ac_catalog }
import from .select_list { SelectItem }

"""Sentinel returned by fuzzy_score when query is not a subsequence of text."""
glob FUZZY_NO_MATCH: int = -9999;

glob _CONSEC_BONUS: int = 5,
     _GAP_PENALTY: int = 2,
     _BOUNDARY_BONUS: int = 10,
     _EXACT_BONUS: int = 100,
     _PATH_FALLBACK_PENALTY: int = 20,
     _FILE_SCAN_CAP: int = 300,
     _MAX_AC_RESULTS: int = 20;

glob _WORD_BOUNDARY_CHARS: str = "/-_. ";

# --- fuzzy scoring ---

"""Score `query` as a case-insensitive subsequence of `text`; lower is better.

Returns FUZZY_NO_MATCH when `query` is not a subsequence of `text`.
Bonuses subtract from the score: consecutive matches, matches at the
start or just after a word-boundary char, and an exact full match.
Gaps between matches add. The ordering this induces is golden-tested
behavior — do not retune the weights.
"""
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

# --- ranking ---

"""A select-list item paired with its fuzzy rank."""
obj _ScoredItem {
    has item: SelectItem = SelectItem(),
        score: int = 0;
}

"""Sort `entries` ascending by score (in place) and return their items.

Manual insertion sort on purpose: na's sort()/sorted() silently ignore
`key=`, and the stable ranking (ties keep source order) is behavior.
"""
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

# --- trigger detection ---

"""Trigger found under the cursor: its kind, raw prefix, and match query."""
obj AutocompleteTrigger {
    has kind: AcKind = AcKind.NONE,
        prefix: str = "",
        query: str = "";
}

"""Detect an autocomplete trigger at the editor cursor.

Slash commands fire only on line 0 while the cursor is still inside the
first word; @file fires for an '@' at a token start with no whitespace
between it and the cursor.
"""
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

# --- candidate sources ---

"""Return the final path component (bytes after the last '/')."""
def _basename(path: str) -> str {
    slash_at = path.rfind("/");
    if slash_at < 0 {
        return path;
    }
    return path[slash_at + 1:];
}

"""Rank the slash-command catalog against `query`; empty query keeps catalog order."""
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

"""Rank candidate file paths against `query`.

Scans at most _FILE_SCAN_CAP files and returns at most _MAX_AC_RESULTS
rows. Basename matches outrank full-path-only matches (the path
fallback carries a fixed penalty).
"""
def _file_items(state: TuiState, query: str) -> list[SelectItem] {
    files = state.files;
    limit = min(len(files), _FILE_SCAN_CAP);

    if not query {
        head = min(limit, _MAX_AC_RESULTS);
        return [SelectItem(value=path, label=_basename(path), description=path) for path in files[:head]];
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

# --- public API ---

"""Refresh autocomplete state from the editor; dismiss when no trigger or items.

Selection survives same-kind updates (so arrowing survives typing) and
resets otherwise, or when it falls off the end of a shrunken item list.
"""
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

"""Splice the selected suggestion into the editor, replacing the trigger prefix."""
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

    # pre-declared: na infers LiteralString from branch assigns and then
    # rejects the other branch's str
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
    state.dirty = True;
}
