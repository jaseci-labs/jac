import random;
import string;
import from typing { Any }
import from jaclang.runtimelib.transport { TransportResponse, Meta }

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
def extract_bearer_token(authorization: str | None, user_manager: Any) -> str | None {
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
    user_manager: Any,
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
