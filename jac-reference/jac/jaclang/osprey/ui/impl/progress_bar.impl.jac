impl ProgressBar.set_value with SetProgress entry {
    self.value = visitor.value;
    if self.value < 0.0 {
        self.value = 0.0;
    }
    if self.value > 1.0 {
        self.value = 1.0;
    }
    visitor.handled = True;
}


impl render_progress(value: float, width: int) -> str {
    if width <= 2 {
        return "#" * max(0, width);
    }
    inner = width - 2;
    filled = int(max(0.0, min(1.0, value)) * float(inner));
    if filled > inner {
        filled = inner;
    }
    return "[" + ("#" * filled) + ("-" * (inner - filled)) + "]";
}


impl progress_measure_height(bar: ProgressBar, max_width: int) -> int {
    _ = (bar, max_width);
    return 1;
}


impl progress_paint_line(bar: ProgressBar, width: int) -> str {
    return render_progress(bar.value, width);
}


impl register_progress_markup(tags: dict[str, object]) {
    tags["ProgressBar"] = ProgressBar;
}
