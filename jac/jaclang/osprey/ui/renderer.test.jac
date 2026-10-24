import from jaclang.osprey.ui.model {
    MainScreen,
    Prompt,
    ApprovalOverlay,
    UiRegion,
    Layer
}

import from jaclang.osprey.ui.mutation { append_child, detach, }

import from jaclang.osprey.ui.layout_types_core { AxisSize }
import from jaclang.osprey.ui.layout_types {
    fill_axis,
    fixed_axis,
    grow_axis,
    intrinsic_axis,
    rect_of
}

import from jaclang.osprey.ui.virtual_terminal { VirtualTerminal, }


node TextRegion(UiRegion) {
    has label: str = "";
}


def _sp(width: AxisSize, height: AxisSize) -> LayoutSpec;


def _fill_fill -> LayoutSpec;


def _grow_region -> LayoutSpec;


def _intrinsic_spec -> LayoutSpec;


def _fixed_height(h: float) -> LayoutSpec;


def _box(w: float, h: float) -> LayoutSpec;


def _rect_of(state: LayoutState, n: UiNode) -> Rect;


obj ShellFixture {
    has renderer: Renderer,
        screen: MainScreen,
        top: TextRegion,
        mid: TextRegion,
        bot: TextRegion;
}


def _shell_renderer(columns: int = 40, rows: int = 12) -> ShellFixture;


def _rows_contain(rows: list[str], needle: str) -> bool;


test "create_renderer owns empty layout registry at terminal size" {
    renderer = create_renderer(40, 12);
    assert renderer.layout.viewport.columns == 40;
    assert renderer.layout.viewport.rows == 12;
    assert renderer.cursor_node_id == "";
    assert renderer.damage == [];
}


test "request_cursor and clear_cursor track a single holder" {
    renderer = create_renderer();
    prompt = Prompt(key="prompt");
    request_cursor(renderer, prompt, row_offset=0, col_offset=2);
    assert renderer.cursor_node_id == node_id(prompt);
    assert renderer.cursor_col_offset == 2;
    clear_cursor(renderer);
    assert renderer.cursor_node_id == "";
}


test "first paint fills expected cells without full clear" {
    shell = _shell_renderer(40, 8);
    renderer = shell.renderer;
    screen = shell.screen;
    term = VirtualTerminal(columns=40, rows=8);
    term.start();
    term.clear_writes();
    result = render_frame(renderer, screen, term);
    cells = term.capture_cells();
    assert cells[0].startswith("TOP");
    assert "mid" in cells[1];
    assert cells[7].startswith("BOT");
    assert result.used_full_clear == False;
    assert frame_used_full_clear(term.writes) == False;
    assert result.sync_wrapped == True;
    term.stop();
}


test "growth damages union of old and new mid bounds and shifts bot" {
    shell = _shell_renderer(40, 10);
    renderer = shell.renderer;
    screen = shell.screen;
    mid = shell.mid;
    bot = shell.bot;
    set_node_contract(renderer, mid, _intrinsic_spec());
    term = VirtualTerminal(columns=40, rows=10);
    term.start();
    render_frame(renderer, screen, term);
    bot_y_before = _rect_of(renderer.layout, bot).y;
    term.clear_writes();

    set_node_content(renderer, mid, ["m0", "m1", "m2", "m3"]);
    mark_semantic_dirty(renderer, mid);
    mark_layout_dirty(renderer, mid);
    result = render_frame(renderer, screen, term);

    bot_y_after = _rect_of(renderer.layout, bot).y;
    assert bot_y_after > bot_y_before;
    assert result.used_full_clear == False;
    assert frame_used_full_clear(term.writes) == False;
    assert damage_cell_count(result.damage) < 40 * 10;
    assert len(result.damage) >= 1;
    cells = term.capture_cells();
    assert cells[bot_y_after].startswith("BOT");
    term.stop();
}


test "shrink repairs uncovered cells without full clear" {
    shell = _shell_renderer(40, 10);
    renderer = shell.renderer;
    screen = shell.screen;
    mid = shell.mid;
    bot = shell.bot;
    set_node_contract(renderer, mid, _intrinsic_spec());
    term = VirtualTerminal(columns=40, rows=10);
    term.start();
    set_node_content(renderer, mid, ["m0", "m1", "m2", "m3"]);
    render_frame(renderer, screen, term);
    mid_before = _rect_of(renderer.layout, mid);
    bot_y_before = _rect_of(renderer.layout, bot).y;
    term.clear_writes();

    set_node_content(renderer, mid, ["m0"]);
    mark_semantic_dirty(renderer, mid);
    mark_layout_dirty(renderer, mid);
    result = render_frame(renderer, screen, term);

    mid_after = _rect_of(renderer.layout, mid);
    bot_y_after = _rect_of(renderer.layout, bot).y;
    assert mid_after.height < mid_before.height;
    assert bot_y_after < bot_y_before;
    assert result.used_full_clear == False;
    assert frame_used_full_clear(term.writes) == False;
    cells = term.capture_cells();
    for row in cells {
        assert "m2" not in row;
        assert "m3" not in row;
    }
    assert cells[bot_y_after].startswith("BOT");
    union_h = mid_before.height;
    damaged_h = 0;
    for d in result.damage {
        damaged_h = max(damaged_h, d.rect.height);
    }
    assert damaged_h >= union_h or damage_cell_count(result.damage) >= mid_before.width;
    term.stop();
}


test "sibling move after height change repaints shifted region" {
    shell = _shell_renderer(40, 10);
    renderer = shell.renderer;
    screen = shell.screen;
    top = shell.top;
    mid = shell.mid;
    bot = shell.bot;
    term = VirtualTerminal(columns=40, rows=10);
    term.start();
    render_frame(renderer, screen, term);
    term.clear_writes();

    set_node_content(renderer, top, ["TOP", "TOP2"]);
    set_node_contract(renderer, top, _fixed_height(2.0));
    mark_layout_dirty(renderer, top);
    result = render_frame(renderer, screen, term);

    assert _rect_of(renderer.layout, mid).y == 2;
    assert _rect_of(renderer.layout, bot).y > 2;
    cells = term.capture_cells();
    assert cells[0].startswith("TOP");
    assert cells[1].startswith("TOP2");
    assert result.used_full_clear == False;
    assert len(result.patch_rects) >= 1;
    term.stop();
}


test "resize recomputes wrap and keeps node ids" {
    renderer = create_renderer(40, 8);
    screen = MainScreen(key="main");
    body = TextRegion(key="body");
    append_child(screen, body);
    set_node_contract(renderer, screen, _intrinsic_spec());
    set_node_contract(renderer, body, _intrinsic_spec());
    set_node_content(renderer, body, ["abcdefghijklmnop"]);
    body_id = node_id(body);

    term = VirtualTerminal(columns=40, rows=8);
    term.start();
    render_frame(renderer, screen, term);
    h1 = _rect_of(renderer.layout, body).height;

    term.inject_resize(8, 8);
    renderer.layout.viewport.columns = 8;
    renderer.layout.viewport.rows = 8;
    mark_layout_dirty(renderer, body);
    result = render_frame(renderer, screen, term);
    h2 = _rect_of(renderer.layout, body).height;

    assert node_id(body) == body_id;
    assert h2 > h1;
    assert result.used_full_clear == False;
    term.stop();
}


test "unicode content paints without corrupting neighbor cells" {
    renderer = create_renderer(20, 4);
    screen = MainScreen(key="main");
    body = TextRegion(key="cjk");
    append_child(screen, body);
    set_node_contract(renderer, screen, _intrinsic_spec());
    set_node_contract(renderer, body, _fixed_height(1.0));
    set_node_content(renderer, body, ["你好"]);

    term = VirtualTerminal(columns=20, rows=4);
    term.start();
    result = render_frame(renderer, screen, term);
    cells = term.capture_cells();
    assert "你" in cells[0] or "你好" in cells[0];
    assert result.used_full_clear == False;
    term.stop();
}


test "overlay close damages old rect and restores underlying cells" {
    renderer = create_renderer(40, 12);
    screen = MainScreen(key="main");
    body = TextRegion(key="body");
    overlay = ApprovalOverlay(key="approval");
    append_child(screen, body);
    screen +>:Layer(z_index=10, modal=True):+> overlay;

    set_node_contract(renderer, screen, _intrinsic_spec());
    set_node_contract(renderer, body, _grow_region());
    set_node_content(renderer, body, ["UNDERLAY"]);
    set_node_contract(renderer, overlay, _box(20.0, 4.0));
    set_node_content(renderer, overlay, ["Approve?", "y/n"]);

    term = VirtualTerminal(columns=40, rows=12);
    term.start();
    render_frame(renderer, screen, term);
    overlay_rect = _rect_of(renderer.layout, overlay);
    assert not overlay_rect.is_empty();
    cells_with = term.capture_cells();
    assert _rows_contain(cells_with, "Approve");
    term.clear_writes();

    detach_node(renderer, overlay);

    for e in [edge screen->:Layer:->overlay] {
        del e;
    }
    detach(overlay);
    result = render_frame(renderer, screen, term);

    cells_after = term.capture_cells();
    assert _rows_contain(cells_after, "UNDERLAY");
    assert not _rows_contain(cells_after, "Approve");
    assert result.used_full_clear == False;
    assert frame_used_full_clear(term.writes) == False;

    covered = False;
    for d in result.damage {
        if d.rect.intersects(overlay_rect) or d.reason == "detach" {
            covered = True;
        }
    }
    assert covered;
    term.stop();
}


test "cursor placed in prompt region and cleared on detach" {
    renderer = create_renderer(40, 6);
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt", draft="hi");
    append_child(screen, prompt);
    set_node_contract(renderer, screen, _intrinsic_spec());
    set_node_contract(renderer, prompt, _fixed_height(1.0));
    set_node_content(renderer, prompt, ["> hi"]);
    request_cursor(renderer, prompt, row_offset=0, col_offset=2);

    term = VirtualTerminal(columns=40, rows=6);
    term.start();
    result = render_frame(renderer, screen, term);
    pr = _rect_of(renderer.layout, prompt);
    assert result.cursor_row == pr.y + 0;
    assert result.cursor_col == pr.x + 2;
    assert renderer.last_cursor_row == result.cursor_row;

    term.clear_writes();
    detach_node(renderer, prompt);
    detach(prompt);

    result2 = render_frame(renderer, screen, term);
    assert renderer.cursor_node_id == "";
    assert result2.cursor_row == -1 or result2.cursor_col == -1;
    term.stop();
}


test "localized semantic edit writes fewer cells than full frame" {
    shell = _shell_renderer(40, 12);
    renderer = shell.renderer;
    screen = shell.screen;
    bot = shell.bot;
    term = VirtualTerminal(columns=40, rows=12);
    term.start();
    render_frame(renderer, screen, term);
    term.clear_writes();

    set_node_content(renderer, bot, ["DONE"]);
    mark_semantic_dirty(renderer, bot);
    result = render_frame(renderer, screen, term);

    full = 40 * 12;
    assert result.cells_written > 0;
    assert result.cells_written < full;
    assert result.used_full_clear == False;
    assert damage_cell_count(result.damage) <= 40 * 2;
    cells = term.capture_cells();
    assert cells[_rect_of(renderer.layout, bot).y].startswith("DONE");
    term.stop();
}


test "desired_cells matches painted virtual terminal snapshot" {
    shell = _shell_renderer(20, 6);
    renderer = shell.renderer;
    screen = shell.screen;
    desired = desired_cells(renderer, screen);
    term = VirtualTerminal(columns=20, rows=6);
    term.start();
    render_frame(renderer, screen, term);
    painted = term.capture_cells();
    assert len(desired) == 6;
    assert desired[0].startswith("TOP");
    assert painted[0].startswith("TOP");
    assert desired[5].startswith("BOT");
    term.stop();
}


test "viewport change between frames adds full-frame resize damage" {
    shell = _shell_renderer(30, 8);
    renderer = shell.renderer;
    screen = shell.screen;
    term = VirtualTerminal(columns=30, rows=8);
    term.start();
    first = render_frame(renderer, screen, term);
    first_has_resize = False;
    for d in first.damage {
        if d.reason == "resize" {
            first_has_resize = True;
        }
    }
    assert not first_has_resize;

    term.inject_resize(30, 10);
    renderer.layout.viewport.columns = 30;
    renderer.layout.viewport.rows = 10;
    second = render_frame(renderer, screen, term);
    second_has_resize = False;
    for d in second.damage {
        if d.reason == "resize" {
            second_has_resize = True;
        }
    }
    assert second_has_resize;
    assert second.used_full_clear == False;

    third = render_frame(renderer, screen, term);
    third_has_resize = False;
    for d in third.damage {
        if d.reason == "resize" {
            third_has_resize = True;
        }
    }
    assert not third_has_resize;
    term.stop();
}


test "resize shrink repaints wrapped rows matching desired snapshot" {
    renderer = create_renderer(40, 6);
    screen = MainScreen(key="main");
    body = TextRegion(key="body");
    append_child(screen, body);
    set_node_contract(renderer, screen, _intrinsic_spec());
    set_node_contract(renderer, body, _intrinsic_spec());
    set_node_content(renderer, body, ["abcdefghijklmnopqrstuvwxyz0123456789"]);

    term = VirtualTerminal(columns=40, rows=6);
    term.start();
    render_frame(renderer, screen, term);
    before = _rect_of(renderer.layout, body);

    term.inject_resize(20, 6);
    renderer.layout.viewport.columns = 20;
    renderer.layout.viewport.rows = 6;
    mark_layout_dirty(renderer, body);
    result = render_frame(renderer, screen, term);

    after = _rect_of(renderer.layout, body);
    assert after.height > before.height;
    assert result.used_full_clear == False;
    assert frame_used_full_clear(term.writes) == False;

    painted = term.capture_cells();
    desired = desired_cells(renderer, screen);
    assert len(painted) == len(desired);
    for i in range(len(desired)) {
        assert painted[i] == desired[i].rstrip();
    }
    term.stop();
}


test "resize grow paints newly exposed rows incrementally" {
    renderer = create_renderer(20, 8);
    screen = MainScreen(key="main");
    top = TextRegion(key="top", label="top");
    body = TextRegion(key="body");
    bot = TextRegion(key="bot", label="bot");
    append_child(screen, top);
    append_child(screen, body);
    append_child(screen, bot);
    set_node_contract(renderer, screen, _intrinsic_spec());
    set_node_contract(renderer, top, _fixed_height(1.0));
    set_node_contract(renderer, body, _grow_region());
    set_node_contract(renderer, bot, _fixed_height(1.0));
    set_node_content(renderer, top, ["TOP"]);
    set_node_content(
        renderer, body, ["r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8"],
    );
    set_node_content(renderer, bot, ["BOT"]);

    term = VirtualTerminal(columns=20, rows=8);
    term.start();
    render_frame(renderer, screen, term);
    assert not _rows_contain(term.capture_cells(), "r7");

    term.inject_resize(20, 11);
    renderer.layout.viewport.columns = 20;
    renderer.layout.viewport.rows = 11;
    result = render_frame(renderer, screen, term);

    cells_big = term.capture_cells();
    assert _rows_contain(cells_big, "r7");
    assert _rows_contain(cells_big, "r8");
    assert result.used_full_clear == False;
    assert frame_used_full_clear(term.writes) == False;
    term.stop();
}


test "overlapping overlays stack by z_index and closing top reveals lower" {
    renderer = create_renderer(40, 10);
    screen = MainScreen(key="main");
    body = TextRegion(key="body");
    lower = ApprovalOverlay(key="lower");
    higher = ApprovalOverlay(key="higher");
    append_child(screen, body);
    screen +>:Layer(z_index=5, modal=False):+> lower;
    screen +>:Layer(z_index=20, modal=True):+> higher;

    set_node_contract(renderer, screen, _intrinsic_spec());
    set_node_contract(renderer, body, _grow_region());
    set_node_content(renderer, body, ["UNDERLAY"]);
    set_node_contract(renderer, lower, _box(40.0, 2.0));
    set_node_content(renderer, lower, ["ALPHA"]);
    set_node_contract(renderer, higher, _box(40.0, 10.0));
    set_node_content(renderer, higher, ["BRAVO"]);

    term = VirtualTerminal(columns=40, rows=10);
    term.start();
    render_frame(renderer, screen, term);
    cells = term.capture_cells();

    assert _rows_contain(cells, "BRAVO");
    assert not _rows_contain(cells, "ALPHA");

    detach_node(renderer, higher);
    for e in [edge screen->:Layer:->higher] {
        del e;
    }
    detach(higher);
    result = render_frame(renderer, screen, term);

    cells_after = term.capture_cells();
    assert _rows_contain(cells_after, "ALPHA");
    assert not _rows_contain(cells_after, "BRAVO");
    assert result.used_full_clear == False;
    assert frame_used_full_clear(term.writes) == False;
    term.stop();
}


test "cursor relocation emits terminal position update at new cell" {
    shell = _shell_renderer(30, 8);
    renderer = shell.renderer;
    screen = shell.screen;
    top = shell.top;
    bot = shell.bot;
    request_cursor(renderer, bot, row_offset=0, col_offset=1);
    term = VirtualTerminal(columns=30, rows=8);
    term.start();
    render_frame(renderer, screen, term);
    bot_rect = _rect_of(renderer.layout, bot);
    assert term.cursor_row == bot_rect.y;
    assert term.cursor_col == bot_rect.x + 1;
    assert term.cursor_visible;

    term.clear_writes();
    request_cursor(renderer, top, row_offset=0, col_offset=2);
    mark_semantic_dirty(renderer, top);
    render_frame(renderer, screen, term);
    top_rect = _rect_of(renderer.layout, top);

    assert term.cursor_row == top_rect.y;
    assert term.cursor_col == top_rect.x + 2;
    assert term.cursor_visible;
    term.stop();
}


test "disjoint edits yield separate small patch rects" {
    shell = _shell_renderer(40, 12);
    renderer = shell.renderer;
    screen = shell.screen;
    top = shell.top;
    bot = shell.bot;
    term = VirtualTerminal(columns=40, rows=12);
    term.start();
    render_frame(renderer, screen, term);
    term.clear_writes();

    set_node_content(renderer, top, ["HEAD"]);
    set_node_content(renderer, bot, ["FOOT"]);
    mark_semantic_dirty(renderer, top);
    mark_semantic_dirty(renderer, bot);
    result = render_frame(renderer, screen, term);

    assert len(result.patch_rects) == 2;
    total_area = 0;
    for r in result.patch_rects {
        assert r.height <= 2;
        total_area += r.width * r.height;
    }
    assert total_area < 40 * 12 / 2;
    cells = term.capture_cells();
    assert cells[0].startswith("HEAD");
    assert cells[_rect_of(renderer.layout, bot).y].startswith("FOOT");

    assert "mid" in cells[1];
    term.stop();
}


test "compute_damage unions prev and current rects after growth" {
    shell = _shell_renderer(30, 10);
    renderer = shell.renderer;
    screen = shell.screen;
    mid = shell.mid;
    set_node_contract(renderer, mid, _intrinsic_spec());
    term = VirtualTerminal(columns=30, rows=10);
    term.start();

    render_frame(renderer, screen, term);
    set_node_content(renderer, mid, ["a", "b", "c", "d"]);
    mark_layout_dirty(renderer, mid);
    relayout(renderer, screen);
    damage = compute_damage(renderer, screen);
    assert len(damage) >= 1;
    total = damage_cell_count(damage);
    assert total >= 30;
    term.stop();
}

impl _sp(width: AxisSize, height: AxisSize) -> LayoutSpec {
    return LayoutSpec(width=width, height=height);
}


impl _fill_fill -> LayoutSpec {
    return _sp(fill_axis(), fill_axis());
}


impl _grow_region -> LayoutSpec {
    return _sp(fill_axis(), grow_axis(1.0));
}


impl _intrinsic_spec -> LayoutSpec {
    return _sp(intrinsic_axis(), intrinsic_axis());
}


impl _fixed_height(h: float) -> LayoutSpec {
    return _sp(fill_axis(), fixed_axis(h));
}


impl _box(w: float, h: float) -> LayoutSpec {
    return _sp(fixed_axis(w), fixed_axis(h));
}


impl _rect_of(state: LayoutState, n: UiNode) -> Rect {
    r = rect_of(state, n);
    if r is None {
        raise AssertionError("no published frame entry for node");
    }
    return r;
}


impl _shell_renderer(columns: int = 40, rows: int = 12) -> ShellFixture {
    renderer = create_renderer(columns, rows);
    screen = MainScreen(key="main");
    top = TextRegion(key="top", label="top");
    mid = TextRegion(key="mid", label="mid");
    bot = TextRegion(key="bot", label="bot");
    append_child(screen, top);
    append_child(screen, mid);
    append_child(screen, bot);
    set_node_contract(renderer, screen, _intrinsic_spec());
    set_node_contract(renderer, top, _fixed_height(1.0));
    set_node_contract(renderer, mid, _grow_region());
    set_node_contract(renderer, bot, _fixed_height(1.0));
    set_node_content(renderer, top, ["TOP"]);
    set_node_content(renderer, mid, ["mid"]);
    set_node_content(renderer, bot, ["BOT"]);
    return ShellFixture(renderer=renderer, screen=screen, top=top, mid=mid, bot=bot,);
}


impl _rows_contain(rows: list[str], needle: str) -> bool {
    for row in rows {
        if needle in row {
            return True;
        }
    }
    return False;
}
