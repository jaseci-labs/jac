def cors_middleware(
    allow_origins: (list[str] | None) = None,
    allow_credentials: bool = True,
    allow_methods: (list[str] | None) = None,
    allow_headers: (list[str] | None) = None,
    expose_headers: (list[str] | None) = None,
    max_age: int = 600
) -> Callable[..., any];

def custom_headers_middleware(
    header_pairs: list[tuple[str, str]]
) -> Callable[..., any];
