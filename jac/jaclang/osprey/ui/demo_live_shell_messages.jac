def _format_turn(role: str, body: str) -> str;


def _next_id(app: LiveShell) -> str;


def _commit_messages(app: LiveShell);


def _push_turn(app: LiveShell, role: str, body: str) -> str;


def _rewrite_turn(app: LiveShell, message_id: str, role: str, body: str);
