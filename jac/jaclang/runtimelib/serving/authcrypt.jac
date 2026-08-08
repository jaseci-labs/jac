import hashlib;
import hmac;
import secrets;
import time;
import from base64 { urlsafe_b64decode, urlsafe_b64encode }
import from json { dumps, loads }


glob SCRYPT_N: int = 16384,
     SCRYPT_R: int = 8,
     SCRYPT_P: int = 1,
     SCRYPT_DKLEN: int = 64,
     SCRYPT_SALT_BYTES: int = 16;


obj JWTError(Exception) {
    has reason: str = 'invalid token';

    def __str__ -> str {
        return self.reason;
    }
}

obj JWTExpiredError(JWTError) {}

def _ac_json_default(o: any) -> str {
    return str(o);
}

def _b64url_encode(data: bytes) -> str {
    return urlsafe_b64encode(data).decode('ascii').rstrip('=');
}

def _b64url_decode(text: str) -> bytes {
    padding = '=' * (-len(text) % 4);
    return urlsafe_b64decode(text + padding);
}

def _normalize_claims(payload: dict[str, any]) -> dict[str, any] {
    import from datetime { datetime }
    normalized = dict(payload);
    for claim in ('exp', 'iat', 'nbf') {
        value = normalized.get(claim);
        if isinstance(value, datetime) {
            normalized[claim] = value.timestamp();
        }
    }
    return normalized;
}

def jwt_encode(payload: dict[str, any], secret: str, algorithm: str = 'HS256') -> str {
    if algorithm != 'HS256' {
        raise JWTError(reason=f"unsupported algorithm: {algorithm}");
    }
    payload = _normalize_claims(payload);
    header = {'alg': 'HS256', 'typ': 'JWT'};
    head_part = _b64url_encode(dumps(header, separators=(',', ':')).encode('utf-8'));
    body_part = _b64url_encode(
        dumps(payload, separators=(',', ':'), default=_ac_json_default).encode('utf-8')
    );
    signing_input = f"{head_part}.{body_part}".encode('ascii');
    signature = hmac.new(
        secret.encode('utf-8'), signing_input, hashlib.sha256
    ).digest();
    return f"{head_part}.{body_part}.{_b64url_encode(signature)}";
}

def jwt_decode(
    token: str,
    secret: str,
    algorithms: (list[str] | None) = None,
    verify_exp: bool = True
) -> dict[str, any] {
    allowed = algorithms if algorithms is not None else ['HS256'];
    if 'HS256' not in allowed {
        raise JWTError(reason='unsupported algorithm list');
    }
    parts = token.split('.');
    if len(parts) != 3 {
        raise JWTError(reason='malformed token');
    }
    (head_part, body_part, sig_part) = (parts[0], parts[1], parts[2]);
    try {
        header = loads(_b64url_decode(head_part));
        payload = loads(_b64url_decode(body_part));
        signature = _b64url_decode(sig_part);
    } except Exception {
        raise JWTError(reason='malformed token');
    }
    if header.get('alg') != 'HS256' {
        raise JWTError(reason='unsupported algorithm');
    }
    signing_input = f"{head_part}.{body_part}".encode('ascii');
    expected = hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest();
    if not hmac.compare_digest(signature, expected) {
        raise JWTError(reason='signature mismatch');
    }
    if verify_exp and 'exp' in payload {
        try {
            expires = float(payload['exp']);
        } except (TypeError, ValueError) {
            raise JWTError(reason='invalid exp claim');
        }
        if time.time() > expires {
            raise JWTExpiredError(reason='token expired');
        }
    }
    if 'nbf' in payload {
        try {
            not_before = float(payload['nbf']);
        } except (TypeError, ValueError) {
            raise JWTError(reason='invalid nbf claim');
        }
        if time.time() < not_before {
            raise JWTError(reason='token not yet valid');
        }
    }
    return payload;
}

def hash_password(password: str, n: int = SCRYPT_N) -> str {
    salt = secrets.token_bytes(SCRYPT_SALT_BYTES);
    digest = hashlib.scrypt(
        password.encode('utf-8'),
        salt=salt,
        n=n,
        r=SCRYPT_R,
        p=SCRYPT_P,
        dklen=SCRYPT_DKLEN
    );
    return (
        f"scrypt${n}${SCRYPT_R}${SCRYPT_P}"
        f"${_b64url_encode(salt)}${_b64url_encode(digest)}"
    );
}

def verify_password(password: str, stored: str) -> bool {
    try {
        parts = stored.split('$');
        if len(parts) != 6 or parts[0] != 'scrypt' {
            return False;
        }
        n = int(parts[1]);
        r = int(parts[2]);
        p = int(parts[3]);
        salt = _b64url_decode(parts[4]);
        expected = _b64url_decode(parts[5]);
        digest = hashlib.scrypt(
            password.encode('utf-8'), salt=salt, n=n, r=r, p=p, dklen=len(expected)
        );
        return hmac.compare_digest(digest, expected);
    } except Exception {
        return False;
    }
}

def new_token_secret -> str {
    return secrets.token_urlsafe(48);
}
