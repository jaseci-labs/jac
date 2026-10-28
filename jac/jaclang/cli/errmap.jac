import os;


glob __all__ = ['humanize_error', 'show_tracebacks'];


def show_tracebacks -> bool;


def _sqlstate(e: Exception) -> str;


def humanize_error(e: Exception) -> (tuple[str, (str | None)] | None);
