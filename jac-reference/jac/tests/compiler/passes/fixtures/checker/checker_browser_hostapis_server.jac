"""Server-context fixture: browser host APIs must NOT leak into server code.

This is a plain `.jac` (server) module. `TextDecoder` is a WHATWG browser
global with no server runtime, so referencing it must stay a real error
here -- the client ambient stubs are gated to client context.
"""

def decode_bytes() -> str {
    d = new(TextDecoder);
    return d.decode("");
}
