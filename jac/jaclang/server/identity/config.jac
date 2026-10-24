glob _active: list[any] = [AuthSettings(), '', None];


def configure_identity(settings: AuthSettings, base_path: str);

def auth_settings -> AuthSettings;

def signing_secret -> str;

def signing_algorithm -> str;

def token_ttl_days -> int;

def password_hash_cost -> int;
