"""Headless logic tests for the phase-6 overlay pickers.

Pure-logic only: exercises SelectList filtering/navigation/key handling and the
command/model/file item builders without opening a terminal, so it runs in CI
with no controlling TTY. Build + run:

  jac nacompile test_pickers.na.jac -o bin/test_pickers && ./bin/test_pickers

All work lives in run_tests(); `with entry` only invokes it. Keeping the body in
a function (not directly under `with entry`) stops the jac formatter from
hoisting locals into module globals. Output goes to fd 1 via tty_write (print is
lint-banned). Exits 0 when every check passes, 1 otherwise.
"""

import sys;

import from .libc_tty { tty_write }
import from .state { TuiState }
import from .select_list { SelectList, SelectItem }
import from .commands { palette_commands, model_items, file_items, MODEL_PRESETS }

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
    emit("test_pickers");
    fails: int = 0;

    state = TuiState();
    state.model_name = "openai/gpt-4o";
    state.files = ["src/app.jac", "src/util.jac", "README.md", "docs/guide.md"];

    # palette entries
    pal = palette_commands(state);
    fails += check("palette exposes /model", _has_value(pal, "open_model"));
    fails += check("palette exposes /files", _has_value(pal, "open_file"));
    fails += check("palette exposes /quit", _has_value(pal, "/quit"));
    fails += check("palette hides /stop when idle", not _has_value(pal, "/stop"));
    state.status = "running";
    fails += check(
        "palette shows /stop when running", _has_value(palette_commands(state), "/stop")
    );

    # model items mirror the presets and flag the current model
    models = model_items(state);
    fails += check(
        "model_items count matches presets", len(models) == len(MODEL_PRESETS)
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

    # file items map the cached file list
    files = file_items(state);
    fails += check("file_items count matches cache", len(files) == 4);
    fails += check("file_items carries paths", files[0].value == "src/app.jac");

    # SelectList substring filter
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

    # navigation wraps
    sl.selected = 0;
    sl.move_up();
    fails += check("move_up from top wraps to last", sl.selected == 3);
    sl.move_down();
    fails += check("move_down from last wraps to first", sl.selected == 0);
    sl.move_down();
    fails += check("move_down advances", sl.selected == 1);

    # handle_key actions
    sl2 = SelectList();
    sl2.reset_items(model_items(state));
    fails += check("typing filters (changed)", sl2.handle_key("g") == "changed");
    fails += check("filter text accrues", sl2.filter_text == "g");
    fails += check("down arrow -> changed", sl2.handle_key("\033[B") == "changed");
    fails += check("enter -> select", sl2.handle_key("\r") == "select");
    fails += check("esc -> cancel", sl2.handle_key("\033") == "cancel");
    fails += check("ctrl+c -> cancel", sl2.handle_key("\003") == "cancel");
    sl2.handle_key("\177");
    fails += check("backspace clears filter char", sl2.filter_text == "");

    # current() bounds
    sl3 = SelectList();
    empty: list[SelectItem] = [];
    sl3.reset_items(empty);
    fails += check("current() is None when empty", sl3.current() is None);

    emit(f"failures={fails}");
    return fails;
}

with entry {
    if run_tests() > 0 {
        sys.exit(1);
    }
}
