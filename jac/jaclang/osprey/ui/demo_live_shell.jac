def _apply_resize(app: LiveShell, columns: int, rows: int);


def _begin_assistant_reply(app: LiveShell, user_text: str);


def _tick_stream(app: LiveShell);


def _accept_approval(app: LiveShell);


def _reject_approval(app: LiveShell);


def _history_up(app: LiveShell);


def _history_down(app: LiveShell);


def _handle_key(app: LiveShell, key: str);


def _handle_host_events(app: LiveShell, events: list[HostEvent]);


def create_live_shell -> LiveShell;


def run_live_shell_demo;
