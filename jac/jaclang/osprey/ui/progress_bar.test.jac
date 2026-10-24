test "render_progress clamps and fills width" {
    assert render_progress(0.0, 10) == "[--------]";
    assert render_progress(1.0, 10) == "[########]";
    mid = render_progress(0.5, 10);
    assert mid.startswith("[");
    assert mid.endswith("]");
    assert len(mid) == 10;
}


test "ProgressBar SetProgress updates value and handles event" {
    bar = ProgressBar(key="p", value=0.0);
    event = SetProgress(value=0.75);
    bar spawn event;
    assert event.handled;
    assert bar.value == 0.75;
}


test "progress_measure_height is one row" {
    bar = ProgressBar(key="p");
    assert progress_measure_height(bar, 40) == 1;
}


test "progress_paint_line uses render_progress" {
    bar = ProgressBar(key="p", value=1.0);
    assert progress_paint_line(bar, 8) == render_progress(1.0, 8);
}


test "register_progress_markup adds ProgressBar tag" {
    tags: dict[str, object] = {};
    register_progress_markup(tags);
    assert "ProgressBar" in tags;
}
