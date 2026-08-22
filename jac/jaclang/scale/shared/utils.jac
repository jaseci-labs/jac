import random;
import string;
import from urllib.parse { urlparse }
import from jaclang.runtimelib.transport { TransportResponse, Meta }

glob _LOOPBACK_HOSTS: set[str] = {'127.0.0.1', 'localhost', '::1'};

def is_safe_loopback_redirect(url: str | None) -> bool {
    if not url {
        return False;
    }
    try {
        parsed = urlparse(url);
    } except Exception {
        return False;
    }
    if parsed.scheme not in ('http', 'https') {
        return False;
    }

    host = parsed.hostname;
    return host in _LOOPBACK_HOSTS;
}

def generate_random_password(length: int = 8) -> str {
    characters = string.ascii_letters + string.digits + string.punctuation;
    password_chars = [random.choice(characters) for _ in range(length)];
    return ''.join(password_chars);
}

def extract_bearer_token(authorization: str | None, user_manager: any) -> str | None {
    token: (str | None) = None;
    if (
        authorization
        and isinstance(authorization, str)
        and authorization.startswith('Bearer ')
    ) {
        token = authorization[7:];
    }
    return user_manager.validate_jwt_token(token) if token else None;
}

def authenticate_or_fail(
    authorization: str | None,
    user_manager: any,
    message: str = 'Authorization required'
) -> tuple[str | None, TransportResponse | None] {
    user_id = extract_bearer_token(authorization, user_manager);
    if not user_id {
        return (
            None,
            TransportResponse.fail(
                code='UNAUTHORIZED',
                message=message,
                meta=Meta(extra={'http_status': 401})
            )
        );
    }
    return (user_id, None);
}
