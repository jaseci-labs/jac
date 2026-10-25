glob API_ROOT: str = "https://api.github.com/repos/";

def headers(agent: str, accept_json: bool = True) -> dict[str, str];

def fetch(
    url: str, agent: str, accept_json: bool = False, timeout: int = 10
) -> bytes | None;

def:protect parse_repo_url(url: str) -> tuple[str, str] | None;
