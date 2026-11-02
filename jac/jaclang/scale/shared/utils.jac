import from urllib.parse { urlparse }

glob _LOOPBACK_HOSTS: set[str] = {'127.0.0.1', 'localhost', '::1'};

def is_safe_loopback_redirect(url: str | None) -> bool;

def _extract_path_param_names(path: (str | None)) -> list[str];

def generate_random_password(length: int = 32) -> str;

def extract_bearer_token(authorization: str | None, user_manager: any) -> str | None;

def authenticate_or_fail(
    authorization: str | None,
    user_manager: any,
    message: str = 'Authorization required'
) -> tuple[str | None, TransportResponse | None];
