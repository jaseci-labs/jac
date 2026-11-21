obj Cell {
    has ch: str = " ",
        style: str = "";
}


obj VirtualTerminal(Terminal) {
    has writes: list[str] = [],
        input_queue: list[str] = [],
        resize_events: list[tuple[int, int]] = [],
        interrupt_count: int = 0,
        exception_exits: int = 0,
        cells: list[list[Cell]] = [],
        cursor_row: int = 0,
        cursor_col: int = 0,
        on_input: Callable[[str], None] | None = None,
        on_resize: Callable[[int, int], None] | None = None,
        on_interrupt: Callable[[], None] | None = None;

    def postinit;
    def _reset_cells;
    def write(data: str) -> None;
    def move_cursor(row: int, col: int);
    def start -> None;
    def stop -> None;
    def inject(data: str);
    def inject_resize(columns: int, rows: int);
    def inject_sigint;
    def run_with_exception_guard(body: Callable[[VirtualTerminal], None]);
    def pending_input -> list[str];
    def poll_input(timeout_s: float = 0.0) -> str;
    def take_input -> list[str];
    def written_text -> str;
    def clear_writes;
    def capture_cells -> list[str];
    def _put_char(ch: str);
    def _apply_output(data: str);
}
