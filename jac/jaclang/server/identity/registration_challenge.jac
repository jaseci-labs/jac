import hashlib;
import secrets;
import hmac;
import from jaclang.server.identity.auth_tokens { AuthTokenStore }

glob CHALLENGE_TTL: int = 300,
     CHALLENGE_MAX: int = 100000,
     CHALLENGE_PURPOSE: str = 'registration-pow';

def issue_challenge -> dict[str, any] {
    salt = secrets.token_hex(24);
    number = secrets.randbelow(CHALLENGE_MAX + 1);
    target = hashlib.sha256((salt + str(number)).encode()).hexdigest();
    token = AuthTokenStore.instance().create_token(
        salt, CHALLENGE_PURPOSE, CHALLENGE_TTL, identity_value=target
    );
    return {
        'token': token,
        'salt': salt,
        'target': target,
        'max_number': CHALLENGE_MAX,
        'expires_in': CHALLENGE_TTL
    };
}

def consume_challenge(proof: dict[str, any] | None) -> bool {
    if not isinstance(proof, dict) {
        return False;
    }
    token = proof.get('token');
    number = proof.get('number');
    if not isinstance(token, str) or len(token) > 128 {
        return False;
    }
    if not isinstance(number, int) or isinstance(number, bool) {
        return False;
    }
    if number < 0 or number > CHALLENGE_MAX {
        return False;
    }
    store = AuthTokenStore.instance();
    record = store.peek_token(token, CHALLENGE_PURPOSE);
    if record is None {
        return False;
    }
    digest = hashlib.sha256((record['user_id'] + str(number)).encode()).hexdigest();
    if not hmac.compare_digest(digest, record['identity_value']) {
        return False;
    }
    return store.consume_token(token, CHALLENGE_PURPOSE) is not None;
}
