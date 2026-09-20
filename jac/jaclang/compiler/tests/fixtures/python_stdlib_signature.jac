"""Bundled stdlib sig: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import json;

def dumps_pos_len() -> int {
    return len(json.dumps("hi"));
}

def dumps_kw_len() -> int {
    return len(json.dumps(obj="hi"));
}
