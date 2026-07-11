# selftest_render.na.jac — dev-only golden-render harness entry.
#
# Compiles to a standalone native binary (no embedded CPython, no trailer) that
# imports the REAL screen_render and dumps framed, byte-exact frames to stdout:
#
#     ===FIXTURE===<fixture.WxH>===
#     <rendered rows>
#     ===END===
#
# The outer runner (scripts/golden_render.py) splits these blocks, captures the
# baseline into tests/golden/tui_render/<fixture.WxH>.txt (--update), and diffs
# subsequent runs. Plan 01 Phase 1 re-points this at Screen.render and asserts
# byte-identical output to the baseline captured here.
#
# Each _run_one builds a FRESH state, because screen_render mutates state
# (_sync_display_rows sets display_rows/layout_cols/layout_dirty=False,
# _clamp_viewport sets viewport_top). Fresh-per-call keeps every frame
# deterministic and independent.
#
# Built by build_selftest.sh (mirrors build_embed.sh's lib-staging, no trailer).

import from .libc_tty { tty_write }
import from .state {
    TuiState,
    Event,
    EventKind,
    TuiStatus,
    OverlayKind,
    OverlayContent,
    OverlaySpec,
    Anchor,
    AcKind
}
import from .select_list { SelectItem }
import from .screen { Screen }
import from .overlay { overlay_build_modal, overlay_composite, overlay_is_active }
import from .runtime { TuiRuntime }


def _run_one(label: str, state: TuiState, cols: int, rows: int) {
    screen = Screen();
    lines = screen.render(state, cols, rows);
    if overlay_is_active(state) {
        modal = overlay_build_modal(state, cols, rows);
        lines = overlay_composite(lines, modal, cols, rows);
    }
    out: str = "===FIXTURE===" + label + "===\n";
    for line in lines {
        out = out + line + "\n";
    }
    out = out + "===END===\n";
    tty_write(1, out);
}


def _runtime_smoke() {
    rt = TuiRuntime();
    state = rt.state;
    state.term_cols = 80;
    state.term_rows = 24;
    lines = rt.screen.render(state, 80, 24);
    ok: str = "OK" if len(lines) == 24 else "FAIL";
    tty_write(1, "===RT_SMOKE===\n" + ok + "\n===END===\n");
}


# ── fixture builders (each returns a fresh TuiState) ──────────────────────────

def build_empty() -> TuiState {
    # Default state: IDLE, empty transcript, empty editor, no model. Exercises
    # the always-on divider + editor + footer path with nothing else.
    return TuiState();
}


def build_streaming() -> TuiState {
    # RUNNING with a populated transcript across several event kinds, including
    # a long ANSWER that wraps across multiple rows at 80 cols. Exercises
    # _transcript_section, build_rows wrapping, and the RUNNING footer.
    s = TuiState();
    s.status = TuiStatus.RUNNING;
    s.model_name = "claude-sonnet-4";
    s.cwd = "~/repo";
    s.events = [
        Event(id=1, kind=EventKind.USER, text="How do I read a file in Python?"),
        Event(
            id=2,
            kind=EventKind.ANSWER,
            text=(
                "You can read a file with `open('path.txt').read()` for small "
                "files, or iterate line by line with `for line in open('p'):` "
                "for large ones. Prefer `pathlib.Path('p').read_text()` for "
                "modern code since it handles encoding and closing for you."
            ),
            node="ans"
        ),
        Event(id=3, kind=EventKind.CALL, text="read_file", node="call"),
        Event(
            id=4,
            kind=EventKind.TOOL_RESULT,
            text="hello world\nline two\nline three",
            node="res"
        )
    ];
    return s;
}


def build_autocomplete() -> TuiState {
    # Active slash-command autocomplete with three items. Exercises _ac_section
    # height accounting (ac_h steals rows from the transcript) and rendering.
    s = TuiState();
    s.ac.active = True;
    s.ac.kind = AcKind.SLASH;
    s.ac.items = [
        SelectItem(value="/help", label="/help", description="Show help"),
        SelectItem(value="/clear", label="/clear", description="Clear transcript"),
        SelectItem(value="/model", label="/model", description="Switch model")
    ];
    s.ac.selected_idx = 0;
    s.ac.query = "";
    return s;
}


def build_warn() -> TuiState {
    # needs_key=True steals one transcript row for the warning. Exercises
    # _warn_row and the t_draw_h = transcript_h - 1 height adjustment.
    s = TuiState();
    s.needs_key = True;
    s.key_env = "OPENAI_API_KEY";
    return s;
}


def build_overlay_at(anchor: Anchor, width_pct: int) -> TuiState {
    # Overlay modal (command palette) over an otherwise-empty screen. Exercises
    # overlay_build_modal + overlay_composite. SelectList.render reads .filtered.
    # anchor/width_pct drive _anchor_place: CENTER,0 reproduces the baseline;
    # BOTTOM / 50%-width prove the Phase 2 placement math.
    s = TuiState();
    s.overlay_stack.push(
        OverlaySpec(
            content=OverlayContent.SELECT_LIST, role=OverlayKind.PALETTE,
            title="Commands", anchor=anchor, width_pct=width_pct
        )
    );
    s.select_list.filtered = [
        SelectItem(value="/help", label="/help", description="Show help"),
        SelectItem(value="/clear", label="/clear", description="Clear transcript"),
        SelectItem(value="/model", label="/model", description="Switch model")
    ];
    s.select_list.selected = 0;
    return s;
}


def build_overlay() -> TuiState {
    return build_overlay_at(Anchor.CENTER, 0);
}


with entry {
    # ── empty_idle: baseline idle screen ──
    _run_one("empty_idle.80x24", build_empty(), 80, 24);
    _run_one("empty_idle.120x30", build_empty(), 120, 30);

    # ── streaming: populated transcript, wrapping, RUNNING footer ──
    _run_one("streaming.80x24", build_streaming(), 80, 24);
    _run_one("streaming.120x30", build_streaming(), 120, 30);
    _run_one("streaming.60x18", build_streaming(), 60, 18);

    # ── autocomplete: active slash menu ──
    _run_one("autocomplete.80x24", build_autocomplete(), 80, 24);

    # ── warn: needs_key warning row ──
    _run_one("warn.80x24", build_warn(), 80, 24);

    # ── overlay: command palette modal composited over base ──
    _run_one("overlay.80x24", build_overlay(), 80, 24);

    # ── overlay placement (Plan 02 Phase 2): anchor + %-width geometry ──
    _run_one("overlay_bottom.80x24", build_overlay_at(Anchor.BOTTOM, 0), 80, 24);
    _run_one("overlay_half.80x24", build_overlay_at(Anchor.CENTER, 50), 80, 24);

    # ── small: height-squeeze path (above _MIN_COLS/_MIN_ROWS) ──
    _run_one("streaming.40x12", build_streaming(), 40, 12);

    # ── tiny: below _MIN_COLS/_MIN_ROWS → blank-rows early return ──
    _run_one("empty_idle.8x4", build_empty(), 8, 4);

    _runtime_smoke();
}
