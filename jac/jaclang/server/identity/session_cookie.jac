import from jaclang.server.identity.config { auth_settings, token_ttl_days }
import from jaclang.server.serving.datatypes { Request, Response }

glob SESSION_COOKIE: str = 'jac_session',
     COOKIE_METHODS: tuple[str, ...] = ('GET', 'HEAD'),
     SESSION_CHANGE: str = 'session_change';


def session_cookie_enabled -> bool {
    return bool(auth_settings().session_cookie);
}

def cookie_values(request: Request, name: str) -> list[str] {
    found: list[str] = [];
    for raw in request.headers.getlist('Cookie') {
        for piece in str(raw).split(';') {
            (key, sep, value) = piece.partition('=');
            if sep and key.strip() == name {
                found.append(value.strip());
            }
        }
    }
    return found;
}

def cookie_session_token(request: Request) -> (str | None) {
    if not session_cookie_enabled() or request.method not in COOKIE_METHODS {
        return None;
    }
    values = cookie_values(request, SESSION_COOKIE);
    if len(values) != 1 or not values[0] {
        return None;
    }
    return values[0];
}

def start_session(request: Request, token: str) {
    setattr(request.state, SESSION_CHANGE, token);
}

def end_session(request: Request) {
    setattr(request.state, SESSION_CHANGE, '');
}

def session_cookie_header(request: Request, token: str) -> str {
    lifetime = token_ttl_days() * 86400 if token else 0;
    parts = [
        SESSION_COOKIE + '=' + token,
        'Path=/',
        'Max-Age=' + str(lifetime),
        'HttpOnly',
        'SameSite=Strict'
    ];
    if request.url.scheme == 'https' {
        parts.append('Secure');
    }
    return '; '.join(parts);
}

def apply_session_change(request: Request, response: Response) {
    change = getattr(request.state, SESSION_CHANGE, None);
    if change is None or not session_cookie_enabled() {
        return;
    }
    response.headers.set('Set-Cookie', session_cookie_header(request, str(change)));
    response.headers.set('Cache-Control', 'no-store');
}

def keep_out_of_shared_caches(response: Response) {
    response.headers.add_vary('Cookie');
    if response.headers.get('Cache-Control') is None {
        response.headers.set('Cache-Control', 'private');
    }
}
