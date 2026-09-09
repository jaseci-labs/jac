import from jaclang.server.settings { AuthSettings }

glob _active: list[any] = [AuthSettings(), '', None];


def configure_identity(settings: AuthSettings, base_path: str) {
    _active[0] = settings;
    _active[1] = base_path;
    _active[2] = None;
}

def auth_settings -> AuthSettings {
    return _active[0];
}

def signing_secret -> str {
    cached = _active[2];
    if cached {
        return str(cached);
    }
    settings: AuthSettings = _active[0];
    secret = settings.resolve_secret(str(_active[1] or ''));
    _active[2] = secret;
    return secret;
}

def signing_algorithm -> str {
    return auth_settings().algorithm;
}

def token_ttl_days -> int {
    return auth_settings().token_ttl_days;
}

def password_hash_cost -> int {
    return auth_settings().password_hash_cost;
}
