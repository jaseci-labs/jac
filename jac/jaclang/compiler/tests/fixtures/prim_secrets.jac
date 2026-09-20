"""Secrets: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import secrets;


def secrets_py -> dict[any, any] {
    rb1000 = secrets.randbelow(1000);
    return {
        "tb16_len": len(secrets.token_bytes(16)),
        "tb0_len": len(secrets.token_bytes(0)),
        "th16_len": len(secrets.token_hex(16)),
        "th0_len": len(secrets.token_hex(0)),
        "tu16_len": len(secrets.token_urlsafe(16)),
        "rb1": secrets.randbelow(1),
        "rb1000_ok": 1 if (rb1000 >= 0 and rb1000 < 1000) else 0,
        "two_differ": 1 if secrets.token_bytes(16) != secrets.token_bytes(16) else 0,

    };
}


def secrets_cl -> dict[any, any] {
    return {};
}


def secrets_na -> dict[str, any] {
    rb1000 = secrets.randbelow(1000);
    return {
        "tb16_len": len(secrets.token_bytes(16)),
        "tb0_len": len(secrets.token_bytes(0)),
        "th16_len": len(secrets.token_hex(16)),
        "th0_len": len(secrets.token_hex(0)),
        "tu16_len": len(secrets.token_urlsafe(16)),
        "rb1": secrets.randbelow(1),
        "rb1000_ok": 1 if (rb1000 >= 0 and rb1000 < 1000) else 0,
        "two_differ": 1 if secrets.token_bytes(16) != secrets.token_bytes(16) else 0,

    };
}
