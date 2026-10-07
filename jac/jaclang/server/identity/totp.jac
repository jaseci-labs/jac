import base64;
import hashlib;
import hmac;
import secrets;
import struct;
import time;
import from urllib.parse { quote }

glob TOTP_DIGITS: int = 6,
     TOTP_PERIOD_SECONDS: int = 30,
     TOTP_SKEW_STEPS: int = 1,
     TOTP_SECRET_BYTES: int = 20;


def new_totp_secret -> str {
    raw = secrets.token_bytes(TOTP_SECRET_BYTES);
    return base64.b32encode(raw).decode('ascii').rstrip('=');
}


def totp_key(secret: str) -> bytes {
    text = secret.strip().replace(' ', '').upper();
    return base64.b32decode(text + ('=' * ((0 - len(text)) % 8)));
}


def totp_code(secret: str, step: int) -> str {
    digest = hmac.new(totp_key(secret), struct.pack('>Q', step), hashlib.sha1).digest();
    offset = digest[len(digest) - 1] & 15;
    number = struct.unpack('>I', digest[offset:offset + 4])[0] & 2147483647;
    return str(number % (10 ** TOTP_DIGITS)).zfill(TOTP_DIGITS);
}


def totp_step(at: (float | None) = None) -> int {
    moment = time.time() if at is None else at;
    return int(moment // TOTP_PERIOD_SECONDS);
}


def normalized_code(code: any) -> str {
    if not isinstance(code, str) {
        return '';
    }
    text = code.replace(' ', '').replace('-', '');
    if len(text) != TOTP_DIGITS or not text.isascii() or not text.isdigit() {
        return '';
    }
    return text;
}


def matching_step(secret: str, code: any, at: (float | None) = None) -> (int | None) {
    presented = normalized_code(code);
    if not presented {
        return None;
    }
    try {
        totp_key(secret);
    } except Exception {
        return None;
    }
    center = totp_step(at);
    matched: (int | None) = None;
    for drift in range(0 - TOTP_SKEW_STEPS, TOTP_SKEW_STEPS + 1) {
        step = center + drift;
        expected = totp_code(secret, step);
        if hmac.compare_digest(expected.encode('ascii'), presented.encode('ascii'))
            and matched is None {
            matched = step;
        }
    }
    return matched;
}


def provisioning_uri(secret: str, account: str, issuer: str) -> str {
    label = quote(issuer, safe='') + ':' + quote(account, safe='');
    return 'otpauth://totp/'
        + label
        + '?secret='
        + secret
        + '&issuer='
        + quote(issuer, safe='')
        + '&algorithm=SHA1&digits='
        + str(TOTP_DIGITS)
        + '&period='
        + str(TOTP_PERIOD_SECONDS);
}
