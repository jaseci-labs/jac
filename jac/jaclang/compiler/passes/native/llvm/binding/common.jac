import atexit;
def _encode_string(s: Any) -> object {
    encoded = s.encode('utf-8');
    return encoded;
}
def _decode_string(b: Any) -> object {
    return b.decode('utf-8');
}
with entry {
    _encode_string.__doc__ = """Encode a string for use by LLVM.""";
    _decode_string.__doc__ = """Decode a LLVM character (byte)string.""";
    _shutting_down = [False];
}
def _at_shutdown() -> object {
    _shutting_down[0] = True;
}
with entry {
    atexit.register(_at_shutdown);
}
"""
    Whether the interpreter is currently shutting down.
    For use in finalizers, __del__ methods, and similar; it is advised
    to early bind this function rather than look it up when calling it,
    since at shutdown module globals may be cleared.
    """
def _is_shutting_down(_shutting_down: Any = _shutting_down) -> object {
    return _shutting_down[0];
}

