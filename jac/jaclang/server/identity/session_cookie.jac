glob SESSION_COOKIE: str = 'jac_session',
     COOKIE_METHODS: tuple[str, ...] = ('GET', 'HEAD'),
     SESSION_CHANGE: str = 'session_change';


def session_cookie_enabled -> bool;

def cookie_values(request: Request, name: str) -> list[str];

def cookie_session_token(request: Request) -> (str | None);

def start_session(request: Request, token: str);

def end_session(request: Request);

def session_cookie_header(request: Request, token: str) -> str;

def apply_session_change(request: Request, response: Response);

def keep_out_of_shared_caches(response: Response);
