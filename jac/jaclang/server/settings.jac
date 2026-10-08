import logging;
import os;
import from jaclang.project.config { JacConfig, ServeConfig }

glob ENV_PREFIX: str = 'JAC_SERVE_',
     WORKERS_AUTO: str = 'auto',
     IDENTIFIER_KINDS: tuple[str, ...] = ('username', 'email'),
     IDENTIFIER_MODES: tuple[str, ...] = ('required', 'optional', 'off'),
     VERIFICATION_MODES: tuple[str, ...] = ('none', 'optional', 'required'),
     PASSWORD_CLASSES: tuple[str, ...] = ('lower', 'upper', 'digit', 'symbol'),
     AUTH_MOVED_KEYS: dict[str, str] = {
         'password_hash_cost': '[serve.auth.password] hash_cost',
         'registration_challenge': '[serve.auth.registration] challenge',
         'registration_attempts_per_hour': '[serve.auth.registration] attempts_per_hour',
         'registration_challenges_per_10_minutes': '[serve.auth.registration] challenges_per_10_minutes'
     },
     SCALE_AUTH_MOVED_KEYS: dict[str, str] = {
         'verify_token_ttl_seconds': '[serve.auth.email] verify_token_ttl_seconds',
         'reset_token_ttl_seconds': '[serve.auth.email] reset_token_ttl_seconds',
         'verify_url_template': '[serve.auth.email] verify_url_template',
         'reset_url_template': '[serve.auth.email] reset_url_template',
         'send_verification_rate_per_hour': '[serve.auth.email] send_verification_per_hour',
         'forgot_password_rate_per_hour': '[serve.auth.email] forgot_password_per_hour'
     },
     logger: logging.Logger = logging.getLogger(__name__);


obj ServeConfigError(Exception) {}


obj WorkerSettings {
    has count: int = 1,
        threads: int = 8,
        max_requests: int = 0,
        max_requests_jitter: int = 0,
        request_timeout: float = 0.0,
        boot_timeout: float = 120.0,
        hang_timeout: float = 30.0;

    def multi_process -> bool {
        return self.count > 1;
    }
}

obj TlsSettings {
    has certfile: str = '',
        keyfile: str = '',
        ca_certs: str = '',
        min_version: str = '1.2';

    def enabled -> bool {
        return bool(self.certfile);
    }

    def build_context -> any;
}

obj ProxySettings {
    has trusted: list[str] = [];
}

obj LimitSettings {
    has max_connections: int = 0,
        backlog: int = 2048,
        max_body_bytes: int = 104857600,
        max_header_bytes: int = 65536,
        max_header_count: int = 100,
        max_request_line_bytes: int = 8192,
        multipart_spool_bytes: int = 1048576;
}

obj TimeoutSettings {
    has header: float = 30.0,
        body: float = 60.0,
        keepalive: float = 65.0,
        drain: float = 10.0,
        close: float = 5.0;
}

obj AccessLogSettings {
    has enabled: bool = True,
        format: str = 'text',
        suppress_health_checks: bool = False;
}

obj CompressionSettings {
    has enabled: bool = True,
        min_bytes: int = 1024,
        level: int = 4;
}

obj WebSocketSettings {
    has allowed_origins: list[str] = [],
        max_message_bytes: int = 0,
        ping_interval: float = 20.0,
        ping_timeout: float = 20.0;
}

obj IdentifierSettings {
    has username: str = 'required',
        email: str = 'optional',
        login_with: list[str] = [];

    def enabled -> list[str];
    def login_identifiers -> list[str];
}

obj UsernameSettings {
    has min_length: int = 1,
        max_length: int = 64,
        pattern: str = '';
}

obj EmailSettings {
    has verification: str = 'none',
        allowed_domains: list[str] = [],
        verify_token_ttl_seconds: int = 86400,
        reset_token_ttl_seconds: int = 1800,
        verify_url_template: str = '',
        reset_url_template: str = '',
        send_verification_per_hour: int = 5,
        forgot_password_per_hour: int = 3;
}

obj PasswordSettings {
    has min_length: int = 8,
        max_length: int = 128,
        require: list[str] = [],
        reject_common: bool = True,
        reject_identifiers: bool = True,
        breached_check: bool = False,
        history: int = 0,
        max_age_days: int = 0,
        hash_cost: int = 14;
}

obj RegistrationSettings {
    has enabled: bool = True,
        challenge: bool = False,
        attempts_per_hour: int = 0,
        challenges_per_10_minutes: int = 0;
}

obj LockoutSettings {
    has max_attempts: int = 10,
        window_seconds: int = 900;
}

obj SecondFactorSettings {
    has issuer: str = '',
        attempts: int = 5,
        lockout_seconds: int = 900,
        challenge_ttl_seconds: int = 300;
}

obj AuthSettings {
    has secret: str = '',
        algorithm: str = 'HS256',
        token_ttl_days: int = 7,
        session_cookie: bool = False,
        identifiers: IdentifierSettings = IdentifierSettings(),
        username: UsernameSettings = UsernameSettings(),
        email: EmailSettings = EmailSettings(),
        password: PasswordSettings = PasswordSettings(),
        registration: RegistrationSettings = RegistrationSettings(),
        lockout: LockoutSettings = LockoutSettings(),
        second_factor: SecondFactorSettings = SecondFactorSettings();

    static def from_table(table: dict[str, any]) -> AuthSettings;
    def problems -> list[str];
    def resolve_secret(base_path: str) -> str;
}

obj ServeSettings {
    has base_path: str = '',
        host: str = '0.0.0.0',
        port: int = 8000,
        strict_port: bool = False,
        dev: bool = False,
        no_client: bool = False,
        client_dist: str = '',
        static_only: bool = False,
        docs_enabled: bool = True,
        graph_enabled: bool = True,
        cors_origins: list[str] = ['*'],
        public_origin: str = '',
        workers: WorkerSettings = WorkerSettings(),
        tls: TlsSettings = TlsSettings(),
        proxy: ProxySettings = ProxySettings(),
        limits: LimitSettings = LimitSettings(),
        timeouts: TimeoutSettings = TimeoutSettings(),
        access_log: AccessLogSettings = AccessLogSettings(),
        compression: CompressionSettings = CompressionSettings(),
        websocket: WebSocketSettings = WebSocketSettings(),
        auth: AuthSettings = AuthSettings();

    static def load(
        base_path: str = '',
        overrides: (dict[str, any] | None) = None,
        config: (JacConfig | None) = None
    ) -> ServeSettings;

    def validate -> list[str];
    def require_valid -> None;
    def scheme -> str {
        return 'https' if self.tls.enabled() else 'http';
    }
}


def secret_home(base_path: str) -> str;
def overlay_table(
    target: object, table: dict[str, any], env: str, section: str, moved: dict[str, str]
) -> None;

def removed_table(config: (JacConfig | None)) -> list[str];


def in_cluster -> bool {
    return bool(os.environ.get('KUBERNETES_SERVICE_HOST', '').strip());
}

def env_value(name: str) -> (str | None) {
    raw = os.environ.get(ENV_PREFIX + name);
    if raw is None {
        return None;
    }
    stripped = raw.strip();
    return stripped;
}

def env_bool(name: str, `default: bool) -> bool {
    raw = env_value(name);
    if raw is None {
        return `default;
    }
    return raw.lower() not in ('0', 'false', 'no', 'off');
}

def env_int(name: str, `default: int) -> int {
    raw = env_value(name);
    if raw is None {
        return `default;
    }
    try {
        return int(raw);
    } except ValueError {
        raise ServeConfigError(f"{ENV_PREFIX}{name} must be an integer, got {raw!r}");
    }
}

def env_float(name: str, `default: float) -> float {
    raw = env_value(name);
    if raw is None {
        return `default;
    }
    try {
        return float(raw);
    } except ValueError {
        raise ServeConfigError(f"{ENV_PREFIX}{name} must be a number, got {raw!r}");
    }
}

def env_list(name: str, `default: list[str]) -> list[str] {
    raw = env_value(name);
    if raw is None {
        return `default;
    }
    return [
        part.strip()
        for part in raw.split(',')
        if part.strip()
    ];
}

def cpu_quota -> int;
def resolve_count(raw: str, quota: int, label: str) -> int;
def default_threads(worker_count: int, quota: int) -> int;
