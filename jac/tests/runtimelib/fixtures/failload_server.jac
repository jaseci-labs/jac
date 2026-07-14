"""Server endpoint module that raises while executing its module body (#6507).

It parses and type-checks fine (so the cl->sv binding for `do_thing` is
recorded), but blows up the moment it is actually imported at serve time. The
serve-side endpoint collector must surface that on the log instead of silently
dropping `do_thing` from the API.
"""

def:pub do_thing -> int {
    return 1;
}

def _explode -> int {
    raise RuntimeError("failload_server: deliberate import-time failure");
}

glob _boom: int = _explode();
