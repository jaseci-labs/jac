glob SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];


def _rule(width: int, ch: str = "─") -> str;


def _pad_to(text: str, width: int) -> str;


def _meter(value: float, width: int) -> str;


def _install_layout(app: LiveShell);


def _header_lines(app: LiveShell) -> list[str];


def _status_line(app: LiveShell) -> str;


def _prompt_lines(app: LiveShell) -> list[str];


def _approval_lines(app: LiveShell) -> list[str];


def _transcript_lines(app: LiveShell) -> list[str];


def _paint(app: LiveShell);


def _render(app: LiveShell);

impl _rule(width: int, ch: str = "─") -> str {
    if width < 1 {
        return "";
    }
    return ch * width;
}


impl _pad_to(text: str, width: int) -> str {
    w = display_width(text);
    if w >= width {
        return truncate_text(text, width, ellipsis="…");
    }
    return text + (" " * (width - w));
}


impl _meter(value: float, width: int) -> str {
    if width < 3 {
        return "▪" * max(0, width);
    }
    inner = width - 2;
    filled = int(max(0.0, min(1.0, value)) * float(inner));
    if filled > inner {
        filled = inner;
    }
    return "▐" + ("█" * filled) + ("░" * (inner - filled)) + "▌";
}


impl _install_layout(app: LiveShell) {
    set_node_contract(
        app.renderer,
        app.shell.screen,
        LayoutSpec(width=fill_axis(), height=fill_axis()),
    );
    set_node_contract(
        app.renderer,
        app.shell.header,
        LayoutSpec(width=fill_axis(), height=fixed_axis(2)),
    );
    set_node_contract(
        app.renderer,
        app.shell.transcript,
        LayoutSpec(width=fill_axis(), height=grow_axis(1.0), scroll_vertical=True),
    );
    set_node_contract(
        app.renderer,
        app.shell.status,
        LayoutSpec(width=fill_axis(), height=fixed_axis(1)),
    );
    set_node_contract(
        app.renderer,
        app.shell.prompt,
        LayoutSpec(width=fill_axis(), height=fixed_axis(3)),
    );
}


impl _header_lines(app: LiveShell) -> list[str] {
    brand = " OSPREY ";
    tag = " osp live ";
    right = (
        str(app.columns) + "×" + str(app.rows) + "  r" + str(app.session.graph_revision)
    );
    mid_pad = app.columns
        - display_width(brand)
        - display_width(tag)
        - display_width(right)
        - 2;
    if mid_pad < 1 {
        mid_pad = 1;
    }
    top = brand + tag + (" " * mid_pad) + right;
    return [_pad_to(top, app.columns), _rule(app.columns, "━")];
}


impl _status_line(app: LiveShell) -> str {
    spin = SPINNER[app.spin_i % len(SPINNER)];
    phase: str = app.phase;
    if app.phase == "streaming" {
        phase = spin + " stream";
    } elif app.phase == "approval" {
        phase = "◈ approve";
    } elif app.phase == "ready" {
        phase = "● ready";
    }
    meter = _meter(app.progress_value, 14);
    left = phase + "  " + meter;
    right = app.status_hint;
    gap = app.columns - display_width(left) - display_width(right) - 2;
    if gap < 1 {
        return truncate_text(left + "  " + right, app.columns, ellipsis="…");
    }
    return left + (" " * gap) + right;
}


impl _prompt_lines(app: LiveShell) -> list[str] {
    draft = app.shell.prompt.draft;
    w = app.columns;
    top = "╭" + _rule(max(0, w - 2), "─") + "╮";
    body_inner = "❯ " + draft;
    body = "│" + _pad_to(body_inner, max(0, w - 2)) + "│";
    if app.phase == "streaming" {
        hint = "streaming — wait for osprey";
    } elif app.shell.approval is not None {
        hint = "modal — a accept · r reject";
    } else {
        hint = "enter send · ↑↓ history · ctrl+u clear";
    }
    hint = truncate_text(hint, max(0, w - 4), ellipsis="…");
    hint_w = display_width(hint);
    fill = max(0, w - 2 - hint_w);
    left = fill // 2;
    right = fill - left;
    foot = "╰" + ("─" * left) + hint + ("─" * right) + "╯";
    return [top, body, foot];
}


impl _approval_lines(app: LiveShell) -> list[str] {
    _ = app;
    inner = 46;
    return [
        "╭" + _rule(inner, "─") + "╮",
        "│" + _pad_to("  TOOL APPROVAL", inner) + "│",
        "│" + _pad_to("", inner) + "│",
        "│" + _pad_to("  jac check  app/ui/renderer.jac", inner) + "│",
        "│" + _pad_to("  mode       read-only verify", inner) + "│",
        "│" + _pad_to("", inner) + "│",
        "│" + _pad_to("  [a] Accept    [r] Reject    [esc]", inner) + "│",
        "╰" + _rule(inner, "─") + "╯",

    ];
}


impl _transcript_lines(app: LiveShell) -> list[str] {
    win = materialize_visible(app.proj);
    if win.lines {
        return win.lines;
    }

    w = max(10, app.columns - 2);
    return [
        "",
        truncate_text("  the graph is live.", w, ellipsis="…"),
        truncate_text("  type below — osprey answers in this frame.", w, ellipsis="…"),
        "",
        truncate_text("  try:  explain retained damage", w, ellipsis="…"),

    ];
}


impl _paint(app: LiveShell) {
    header = _header_lines(app);
    lines = _transcript_lines(app);
    status = _status_line(app);
    prompt_lines = _prompt_lines(app);

    if app.shell.approval is not None {
        overlay = _approval_lines(app);
        set_node_contract(
            app.renderer,
            app.shell.approval,
            LayoutSpec(width=fixed_axis(48), height=fixed_axis(len(overlay))),
        );
        set_node_content(app.renderer, app.shell.approval, overlay);
        mark_semantic_dirty(app.renderer, app.shell.approval);
        mark_layout_dirty(app.renderer, app.shell.approval);
    }

    set_node_content(app.renderer, app.shell.header, header);
    set_node_content(app.renderer, app.shell.transcript, lines);
    set_node_content(app.renderer, app.shell.status, [status]);
    set_node_content(app.renderer, app.shell.prompt, prompt_lines);
    mark_semantic_dirty(app.renderer, app.shell.header);
    mark_semantic_dirty(app.renderer, app.shell.transcript);
    mark_semantic_dirty(app.renderer, app.shell.status);
    mark_semantic_dirty(app.renderer, app.shell.prompt);
    mark_layout_dirty(app.renderer, app.shell.screen);

    draft_w = display_width(app.shell.prompt.draft);
    cursor_col = 1 + 2 + draft_w;
    max_col = app.columns - 2;
    if cursor_col > max_col {
        cursor_col = max_col;
    }
    request_cursor(app.renderer, app.shell.prompt, row_offset=1, col_offset=cursor_col);
}


impl _render(app: LiveShell) {
    if not app.dirty {
        return;
    }
    _paint(app);
    frame = render_frame(app.renderer, app.shell.screen, app.term);
    if frame.cursor_row >= 0 {
        app.term.show_cursor();
    } else {
        app.term.hide_cursor();
    }
    app.dirty = False;
}
