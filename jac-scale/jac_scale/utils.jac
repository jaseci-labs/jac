import random;
import string;
import from urllib.parse { urlparse }
import from jaclang.runtimelib.transport { TransportResponse, Meta }

# Hosts that resolve to the local machine. A redirect target is only trusted
# for token delivery when its host is one of these — see is_safe_loopback_redirect.
glob _LOOPBACK_HOSTS: set[str] = {'127.0.0.1', 'localhost', '::1'};

"""Whether a URL is a safe loopback target for delivering an auth token.

Desktop / "thin client" apps serve their UI from http://127.0.0.1:<port> and
ask the SSO flow to redirect the token back to that loopback origin (RFC 8252,
"OAuth 2.0 for Native Apps"). The requested URL arrives untrusted (it round-trips
through the OAuth provider via the `state` parameter), so it must be validated
before we redirect a token to it: an attacker who can influence `state` could
otherwise turn the callback into an open redirect and exfiltrate the token.

Trusted only when the scheme is http/https AND the host is a loopback address.
Any parse failure or non-loopback host returns False.
"""
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
    # `hostname` strips the port and brackets (e.g. [::1]) and lowercases the
    # host, so a crafted "127.0.0.1.evil.com" does not match a loopback host.
    host = parsed.hostname;
    return host in _LOOPBACK_HOSTS;
}

"""Extract path parameter names from a URL path template."""
def _extract_path_param_names(path: (str | None)) -> list[str] {
    if not path {
        return [];
    }
    param_names: list[str] = [];
    for segment in path.split('/') {
        if (segment.startswith('{') and segment.endswith('}') and (len(segment) > 2)) {
            raw_param = segment[1:-1].strip();
            if raw_param {
                param_name = raw_param.split(':', 1)[0].strip();
                if (param_name and not (param_name in param_names)) {
                    param_names.append(param_name);
                }
            }
        }
    }
    return param_names;
}

"""Generate a random password with specified length.

Args:
    length: The length of the password to generate (default: 8)

Returns:
    A random password string containing letters, digits, and special characters
"""
def generate_random_password(length: int = 8) -> str {
    characters = string.ascii_letters + string.digits + string.punctuation;
    password_chars = [random.choice(characters) for _ in range(length)];
    return ''.join(password_chars);
}

"""Extract Bearer token from Authorization header and validate via user_manager.

Returns the authenticated user_id or None.
"""
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

"""Extract Bearer token and return (user_id, None) on success or (None, error_response) on failure."""
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
