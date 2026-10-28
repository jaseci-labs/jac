walker SetProgress {
    has value: float = 0.0,
        handled: bool = False;
}


node ProgressBar {
    has key: str = "",
        value: float = 0.0;

    can set_value with SetProgress entry;
}


def render_progress(value: float, width: int) -> str;


def progress_measure_height(bar: ProgressBar, max_width: int) -> int;


def progress_paint_line(bar: ProgressBar, width: int) -> str;


def register_progress_markup(tags: dict[str, object]);
