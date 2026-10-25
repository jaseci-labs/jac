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
