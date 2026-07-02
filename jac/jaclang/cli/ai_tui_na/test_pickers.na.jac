import sys;

import from .libc_tty { tty_write }
import from .state { TuiState }
import from .select_list { SelectList, SelectItem }
import from .commands { palette_commands, model_items, file_items, resolve_slash_line }
import from .autocomplete { fuzzy_score, ac_update, ac_apply }
import from .keys {
    parse_key,
    KK_UP,
    KK_DOWN,
    KK_CTRL,
    KK_ESCAPE,
    KK_ENTER,
    KK_BACKSPACE,
    KK_CHAR,
    KK_SHIFT_ENTER,
    KK_WORD_LEFT,
    KK_UNKNOWN
}

def emit(line: str) {
    tty_write(1, line + "\n");
}

def check(name: str, cond: bool) -> int {
    if cond {
        emit(f"  ok   {name}");
        return 0;
    }
    emit(f"  FAIL {name}");
    return 1;
}

def _has_value(items: list[SelectItem], value: str) -> bool {
    i: int = 0;
    while i < len(items) {
        if items[i].value == value {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def run_tests -> int {
    tty_write(2, "test_pickers: run_tests reached\n");
    emit("test_pickers");
    fails: int = 0;

    state = TuiState();
    state.model_name = "openai/gpt-4o";
    state.model_presets = [
        "anthropic/claude-opus-4-7",
        "anthropic/claude-sonnet-4-6",
        "openai/gpt-4o",
        "ollama/gemma4:31b",
        "local:gemma-4-e4b"
    ];
    state.files = ["src/app.jac", "src/util.jac", "README.md", "docs/guide.md"];

    pal = palette_commands(state);
    fails += check("palette exposes /model", _has_value(pal, "open_model"));
    fails += check("palette exposes /files", _has_value(pal, "open_file"));
    fails += check("palette exposes /quit", _has_value(pal, "/quit"));
    fails += check("palette hides /stop when idle", not _has_value(pal, "/stop"));
    state.status = "running";
    fails += check(
        "palette shows /stop when running", _has_value(palette_commands(state), "/stop")
    );

    fails += check("resolve /exit -> /quit", resolve_slash_line("/exit") == "/quit");
    fails += check("resolve /q -> /quit", resolve_slash_line("/q") == "/quit");
    fails += check(
        "resolve /clear -> /clear", resolve_slash_line("/clear") == "/clear"
    );
    fails += check(
        "resolve /models -> open_model", resolve_slash_line("/models") == "open_model"
    );

    models = model_items(state);
    fails += check(
        "model_items count matches presets", len(models) == len(state.model_presets)
    );
    cur_marked: bool = False;
    mi: int = 0;
    while mi < len(models) {
        if models[mi].value == "openai/gpt-4o" {
            if models[mi].description == "current" {
                cur_marked = True;
            }
        }
        mi += 1;
    }
    fails += check("model_items marks current model", cur_marked);

    files = file_items(state);
    fails += check("file_items count matches cache", len(files) == 4);
    fails += check("file_items carries paths", files[0].value == "src/app.jac");

    sl = SelectList();
    sl.reset_items(file_items(state));
    sl.set_filter("util");
    fails += check("filter 'util' narrows to 1", len(sl.filtered) == 1);
    sl.set_filter("src/");
    fails += check("filter 'src/' narrows to 2", len(sl.filtered) == 2);
    sl.set_filter("zzz");
    fails += check("filter 'zzz' narrows to 0", len(sl.filtered) == 0);
    sl.set_filter("");
    fails += check("empty filter restores all", len(sl.filtered) == 4);

    sl.selected = 0;
    sl.move_up();
    fails += check("move_up from top wraps to last", sl.selected == 3);
    sl.move_down();
    fails += check("move_down from last wraps to first", sl.selected == 0);
    sl.move_down();
    fails += check("move_down advances", sl.selected == 1);

    sl2 = SelectList();
    sl2.reset_items(model_items(state));
    fails += check(
        "typing filters (changed)", sl2.handle_key(parse_key("g")) == "changed"
    );
    fails += check("filter text accrues", sl2.filter_text == "g");
    fails += check(
        "down arrow -> changed", sl2.handle_key(parse_key("\033[B")) == "changed"
    );
    fails += check("enter -> select", sl2.handle_key(parse_key("\r")) == "select");
    fails += check("esc -> cancel", sl2.handle_key(parse_key("\033")) == "cancel");
    fails += check("ctrl+c -> cancel", sl2.handle_key(parse_key("\003")) == "cancel");
    sl2.handle_key(parse_key("\177"));
    fails += check("backspace clears filter char", sl2.filter_text == "");

    sl3 = SelectList();
    empty: list[SelectItem] = [];
    sl3.reset_items(empty);
    fails += check("current() is None when empty", sl3.current() is None);

    fails += check("parse_key CSI up -> UP", parse_key("\033[A").kind == KK_UP);
    fails += check("parse_key SS3 up -> UP", parse_key("\033OA").kind == KK_UP);
    fails += check("parse_key CSI down -> DOWN", parse_key("\033[B").kind == KK_DOWN);
    fails += check("parse_key SS3 down -> DOWN", parse_key("\033OB").kind == KK_DOWN);
    fails += check(
        "parse_key ctrl-c -> CTRL c",
        parse_key("\003").kind == KK_CTRL and parse_key("\003").code == 99
    );
    fails += check("parse_key ctrl-q -> CTRL q", parse_key("\021").code == 113);
    fails += check("parse_key bare esc -> ESCAPE", parse_key("\033").kind == KK_ESCAPE);
    fails += check("parse_key enter -> ENTER", parse_key("\r").kind == KK_ENTER);
    fails += check(
        "parse_key backspace -> BACKSPACE", parse_key("\177").kind == KK_BACKSPACE
    );
    fails += check(
        "parse_key printable -> CHAR",
        parse_key("a").kind == KK_CHAR and parse_key("a").code == 97
    );
    fails += check(
        "parse_key shift-enter (\\033\\r) -> SHIFT_ENTER",
        parse_key("\033\r").kind == KK_SHIFT_ENTER
    );
    fails += check(
        "parse_key word-left variants -> WORD_LEFT",
        parse_key("\033[1;5D").kind == KK_WORD_LEFT
        and parse_key("\033b").kind == KK_WORD_LEFT
    );
    fails += check("parse_key empty -> UNKNOWN", parse_key("").kind == KK_UNKNOWN);

    fails += check("fuzzy empty query -> 0", fuzzy_score("", "model") == 0);
    fails += check("fuzzy no match -> -9999", fuzzy_score("xyz", "model") == -9999);
    fails += check(
        "fuzzy exact match scores very low", fuzzy_score("model", "model") < -50
    );
    fails += check("fuzzy subsequence matches", fuzzy_score("mo", "model") != -9999);
    fails += check(
        "fuzzy longer-than-text -> no match", fuzzy_score("modelx", "model") == -9999
    );
    fails += check(
        "fuzzy consec beats scattered",
        fuzzy_score("mo", "model") < fuzzy_score("mo", "macro")
    );

    ac_s = TuiState();
    ac_s.files = ["src/app.jac", "src/util.jac", "README.md", "docs/api.md"];
    ac_s.model_presets = ["anthropic/claude-sonnet-4-6"];

    ac_update(ac_s);
    fails += check("ac: empty editor -> inactive", not ac_s.ac.active);

    ac_s.editor.lines = ["/"];
    ac_s.editor.cursor_col = 1;
    ac_update(ac_s);
    fails += check("ac: / -> active", ac_s.ac.active);
    fails += check("ac: / kind=slash", ac_s.ac.kind == "slash");
    fails += check("ac: / -> 6 commands", len(ac_s.ac.items) == 6);

    ac_s2 = TuiState();
    ac_s2.files = ["src/app.jac"];
    ac_s2.editor.lines = ["/m"];
    ac_s2.editor.cursor_col = 2;
    ac_update(ac_s2);
    fails += check("ac: /m -> active", ac_s2.ac.active);
    has_model: bool = False;
    aci: int = 0;
    while aci < len(ac_s2.ac.items) {
        if ac_s2.ac.items[aci].value == "/model" {
            has_model = True;
        }
        aci = aci + 1;
    }
    fails += check("ac: /m -> /model in items", has_model);

    ac_s3 = TuiState();
    ac_s3.files = [];
    ac_s3.editor.lines = ["/zzz"];
    ac_s3.editor.cursor_col = 4;
    ac_update(ac_s3);
    fails += check("ac: /zzz -> dismissed", not ac_s3.ac.active);

    ac_f = TuiState();
    ac_f.files = ["src/app.jac", "src/util.jac", "README.md"];
    ac_f.editor.lines = ["look at @src"];
    ac_f.editor.cursor_col = 12;
    ac_update(ac_f);
    fails += check("ac: @src -> active", ac_f.ac.active);
    fails += check("ac: @src kind=at_file", ac_f.ac.kind == "at_file");
    fails += check("ac: @src -> 2 file matches", len(ac_f.ac.items) == 2);

    ac_f2 = TuiState();
    ac_f2.files = ["src/app.jac"];
    ac_f2.editor.lines = ["@zzz"];
    ac_f2.editor.cursor_col = 4;
    ac_update(ac_f2);
    fails += check("ac: @zzz no files -> inactive", not ac_f2.ac.active);

    ac_n = TuiState();
    ac_n.files = [];
    ac_n.editor.lines = ["/"];
    ac_n.editor.cursor_col = 1;
    ac_update(ac_n);
    fails += check("ac nav: starts at 0", ac_n.ac.selected_idx == 0);
    ac_n.ac.nav_down();
    fails += check("ac nav: down -> 1", ac_n.ac.selected_idx == 1);
    ac_n.ac.selected_idx = 0;
    ac_n.ac.nav_up();
    fails += check("ac nav: up from 0 wraps to 5", ac_n.ac.selected_idx == 5);
    ac_n.ac.dismiss();
    fails += check("ac nav: dismiss clears active", not ac_n.ac.active);

    ac_ap = TuiState();
    ac_ap.files = [];
    ac_ap.editor.lines = ["/mo"];
    ac_ap.editor.cursor_col = 3;
    ac_update(ac_ap);
    ac_ap.ac.selected_idx = 0;
    ac_apply(ac_ap);
    applied_text = ac_ap.editor.lines[0];
    fails += check("ac apply: slash replaces prefix", applied_text == "/model ");
    fails += check("ac apply: cursor after insertion", ac_ap.editor.cursor_col == 7);
    fails += check("ac apply: ac dismissed", not ac_ap.ac.active);

    ac_af = TuiState();
    ac_af.files = ["src/app.jac", "src/util.jac"];
    ac_af.editor.lines = ["check @app"];
    ac_af.editor.cursor_col = 10;
    ac_update(ac_af);
    fails += check("ac at_file: @app triggers", ac_af.ac.active);
    ac_af.ac.selected_idx = 0;
    ac_apply(ac_af);
    af_text = ac_af.editor.lines[0];
    fails += check("ac at_file: apply inserts @path", af_text.startswith("check @"));
    fails += check("ac at_file: ac dismissed after apply", not ac_af.ac.active);

    emit(f"failures={fails}");
    return fails;
}

with entry {
    if run_tests() > 0 {
        sys.exit(1);
    }
}
