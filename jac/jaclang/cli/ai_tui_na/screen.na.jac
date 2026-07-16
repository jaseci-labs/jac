# Screen composer — owned module functions + Component types for D2.

import from .state { TuiState }
import from .transcript {
    TranscriptView,
    sync_display_rows,
    clamp_viewport,
    render_transcript
}
import from .warn_view { WarnView, render_warn }
import from .autocomplete_view { AutocompleteView, render_ac }
import from .editor_view { editor_preferred_height, render_editor }
import from .status { StatusView, render_status }
import from .chrome { divider_row }

glob _MIN_COLS: int = 10,
     _MIN_ROWS: int = 6,
     _AC_MAX_VISIBLE: int = 8;

obj ScreenLayout {
    has editor_h: int = 0,
        ac_h: int = 0,
        transcript_h: int = 0,
        show_warn: bool = False,
        t_draw_h: int = 0;
}

obj Screen {
    has transcript: TranscriptView = TranscriptView(),
        warn: WarnView = WarnView(),
        ac: AutocompleteView = AutocompleteView(),
        status: StatusView = StatusView();

    def layout(state: TuiState, cols: int, rows: int) -> ScreenLayout {
        editor_h = editor_preferred_height(state, cols, rows);
        ac_h = min(_AC_MAX_VISIBLE, len(state.ac.items)) if state.ac.active else 0;
        transcript_h = max(0, rows - 1 - editor_h - ac_h - 1);
        show_warn = state.needs_key;
        t_draw_h = max(0, transcript_h - 1) if show_warn else transcript_h;

        sync_display_rows(state, cols);
        clamp_viewport(state, t_draw_h);

        return ScreenLayout(
            editor_h=editor_h,
            ac_h=ac_h,
            transcript_h=transcript_h,
            show_warn=show_warn,
            t_draw_h=t_draw_h
        );
    }

    def render(state: TuiState, cols: int, rows: int) -> list[str] {
        if cols < _MIN_COLS or rows < _MIN_ROWS {
            return ["" for _ in range(rows)];
        }
        ly = self.layout(state, cols, rows);

        out: list[str] = [];
        out.extend(render_transcript(state, cols, ly.t_draw_h));
        if ly.show_warn {
            out.extend(render_warn(state, cols));
        }
        if state.ac.active and ly.ac_h > 0 {
            out.extend(render_ac(state, cols, ly.ac_h));
        }
        out.append(divider_row("├", "┤", cols));
        out.extend(render_editor(state, cols, ly.editor_h));
        out.extend(render_status(state, cols));
        return out;
    }
}
