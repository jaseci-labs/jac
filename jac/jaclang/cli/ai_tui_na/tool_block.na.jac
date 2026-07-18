import from .terminal { ANSI_RESET }
import from .width { visible_width, ansi_trunc, ansi_pad }
import from .state { DisplayRow, EventKind }
import from .theme {
    TH_SGR_CALL_BOLD,
    TH_SGR_REASON_DIM,
    TH_SGR_OK_BOLD,
    TH_SGR_ERROR_BOLD
}

glob _CALL_ICON: str = "⚙ ",
     _OK_ICON: str = "✓ ",
     _ERR_ICON: str = "✗ ",
     _NAME_ARGS_GAP: str = "  ",
     _RESULT_INDENT: str = "  ";

glob _MIN_ARGS_COLS: int = 2;

def tool_call_rows(tool_name: str, text: str, width: int, out: list[DisplayRow]) {
    name = tool_name if tool_name else "tool";
    header_vis = visible_width(_CALL_ICON) + visible_width(name) + visible_width(
        _NAME_ARGS_GAP
    );

    args_avail = width - header_vis;
    args_line: str = "";
    if args_avail > _MIN_ARGS_COLS and text {
        args_line = ansi_trunc(text, args_avail);
    }

    row = TH_SGR_CALL_BOLD + _CALL_ICON + name + TH_SGR_REASON_DIM + _NAME_ARGS_GAP + args_line;
    out.append(
        DisplayRow(
            text=ansi_pad(row, width) + ANSI_RESET,
            kind=EventKind.CALL,
            is_continuation=False,
            pre_styled=True
        )
    );
}

def tool_result_rows(tool_name: str, text: str, width: int, out: list[DisplayRow]) {
    is_err = len(text) == 0;
    icon = _ERR_ICON if is_err else _OK_ICON;
    icon_sgr = TH_SGR_ERROR_BOLD if is_err else TH_SGR_OK_BOLD;
    dim_sgr = TH_SGR_REASON_DIM;
    body = text if text else "(empty)";
    avail = max(1, width - visible_width(_RESULT_INDENT));

    for (i, line) in enumerate(body.split("\n")) {
        is_cont = i > 0;
        lead = (dim_sgr + _RESULT_INDENT) if is_cont else (icon_sgr + icon + dim_sgr);
        row = lead + ansi_trunc(line, avail);
        out.append(
            DisplayRow(
                text=ansi_pad(row, width) + ANSI_RESET,
                kind=EventKind.TOOL_RESULT,
                is_continuation=is_cont,
                pre_styled=True
            )
        );
    }
}
