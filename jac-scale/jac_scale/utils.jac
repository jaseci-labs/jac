import random;
import string;

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
