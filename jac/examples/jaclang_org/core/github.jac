import from jaclang.data.contracts { JsonEndpoint }

glob API_ROOT: str = "https://api.github.com/repos/",
     CODELOAD_ROOT: str = "https://codeload.github.com/",
     CHUNK_BYTES: int = 262144;

obj RepoMeta {
    has full_name: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        default_branch: str = "main",
        stars: int = 0,
        forks: int = 0,
        size_kb: int = 0,
        topics: list[str] = [],
        pushed_at: str = "",
        created_at: str = "";
}

def headers(agent: str, accept_json: bool = True) -> dict[str, str];

def fetch(
    url: str, agent: str, accept_json: bool = False, timeout: int = 10
) -> bytes | None;

def:protect parse_repo_url(url: str) -> tuple[str, str] | None;

def:protect repo_meta(repo: str, agent: str) -> RepoMeta | None;

def:protect head_sha(repo: str, ref: str, agent: str) -> str;

def:protect download_tarball(
    repo: str,
    ref: str,
    agent: str,
    max_bytes: int = 0,
    on_bytes: Callable[[int], None] | None = None
) -> bytes | None;

def _wanted(
    rel: str,
    prefixes: list[str] | None,
    suffixes: list[str] | None,
    names: list[str] | None
) -> bool;

def:protect untar(
    data: bytes,
    prefixes: list[str] | None = None,
    suffixes: list[str] | None = None,
    names: list[str] | None = None,
    max_member_bytes: int = 0
) -> dict[str, bytes];

def:protect code_breakdown(data: bytes) -> tuple[int, int];

def:protect text_of(blob: bytes) -> str;

def mb_of(byte_count: int) -> str;
