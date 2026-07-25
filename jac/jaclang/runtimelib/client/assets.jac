import re;
import from enum { StrEnum }
import from pathlib { Path }

glob ASSET_MEDIA_TYPES: dict[str, str] = {
         '.avif': 'image/avif',
         '.css': 'text/css; charset=utf-8',
         '.eot': 'application/vnd.ms-fontobject',
         '.gif': 'image/gif',
         '.htm': 'text/html; charset=utf-8',
         '.html': 'text/html; charset=utf-8',
         '.ico': 'image/x-icon',
         '.jpeg': 'image/jpeg',
         '.jpg': 'image/jpeg',
         '.js': 'text/javascript; charset=utf-8',
         '.json': 'application/json; charset=utf-8',
         '.map': 'application/json; charset=utf-8',
         '.mjs': 'text/javascript; charset=utf-8',
         '.mp3': 'audio/mpeg',
         '.mp4': 'video/mp4',
         '.otf': 'font/otf',
         '.pdf': 'application/pdf',
         '.png': 'image/png',
         '.svg': 'image/svg+xml',
         '.ttf': 'font/ttf',
         '.txt': 'text/plain; charset=utf-8',
         '.wasm': 'application/wasm',
         '.wav': 'audio/wav',
         '.webm': 'video/webm',
         '.webp': 'image/webp',
         '.woff': 'font/woff',
         '.woff2': 'font/woff2',
         '.xml': 'application/xml; charset=utf-8'
     };

glob SOURCE_ONLY_EXTENSIONS: set[str] = {
         '.jac',
         '.jsx',
         '.less',
         '.py',
         '.pyc',
         '.sass',
         '.scss',
         '.styl',
         '.ts',
         '.tsx'
     };

glob ASSET_COPY_EXTENSIONS: set[str] = set(ASSET_MEDIA_TYPES.keys()) | {
         '.less',
         '.sass',
         '.scss',
         '.styl'
     };

glob RESERVED_URL_PREFIXES: list[str] = [
         'walker/',
         'walkers',
         'function/',
         'functions',
         'user/',
         'protected',
         'healthz',
         'graph',
         'docs',
         '__build_status',
         '__jac'
     ];

glob _HASHED_TOKEN_RE: str = r'[._-]([A-Za-z0-9_]{8,})(?:\.[A-Za-z0-9]+)+$',
     _CACHE_BUST_KEYS: list[str] = ['hash', 'v', 'version'],
     _HEX_DIGITS: str = '0123456789abcdefABCDEF';

enum AssetOutcome(StrEnum) {
    SERVED = 'served',
    NOT_AN_ASSET = 'not_an_asset',
    NOT_FOUND = 'not_found',
    FORBIDDEN = 'forbidden'
}

enum AssetRootMode(StrEnum) {
    BUILD_OUTPUT = 'build-output',
    PUBLIC = 'public',
    SOURCE_ASSET = 'source-asset'
}

obj AssetRoot {
    has path: Path,
        mode: str = AssetRootMode.SOURCE_ASSET.value,
        flatten: bool = False;
}

obj AssetPolicy {
    has roots: list[AssetRoot] = [],
        extensions: set[str] = set(),
        reserved_prefixes: list[str] = [],
        dev: bool = False,
        immutable_max_age: int = 31536000;

    static def from_config(
        base_path: (Path | None) = None, dev: bool = False
    ) -> AssetPolicy;
}

obj AssetResolution {
    has outcome: str,
        status: int = 200,
        path: (Path | None) = None,
        media_type: str = 'text/plain; charset=utf-8',
        cache_control: str = 'no-cache',
        etag: str = '',
        last_modified: str = '',
        message: str = '';

    def is_served -> bool {
        return self.outcome == AssetOutcome.SERVED.value;
    }

    def headers -> dict[str, str];
    def read_bytes -> bytes;
    def is_fresh(
        if_none_match: (str | None) = None, if_modified_since: (str | None) = None
    ) -> bool;
}

obj AssetResolver {
    has policy: AssetPolicy;

    static def build(
        dev: bool = False, base_path: (Path | None) = None
    ) -> AssetResolver;

    def resolve(url_path: str, query: str = "") -> AssetResolution;
    def _locate(rel: str) -> (Path | None);
    def _describe(file_path: Path, cache_bust: bool) -> AssetResolution;
}

def parse_byte_range(
    range_header: (str | None), size: int
) -> (tuple[(int, int)] | None) {
    if not range_header or size <= 0 {
        return None;
    }
    text = range_header.strip();
    if not text.startswith('bytes=') or (',' in text) {
        return None;
    }
    spec = text[6:].strip();
    if '-' not in spec {
        return None;
    }
    (raw_start, _, raw_end) = spec.partition('-');
    try {
        if not raw_start {
            length = int(raw_end);
            if length <= 0 {
                return None;
            }
            start = max(0, size - length);
            end = size - 1;
        } else {
            start = int(raw_start);
            end = int(raw_end) if raw_end else (size - 1);
        }
    } except ValueError {
        return None;
    }
    end = min(end, size - 1);
    if start > end or start >= size {
        return None;
    }
    return (start, end);
}

def _as_dict(value: any) -> dict[str, any] {
    return value if isinstance(value, dict) else {};
}

def _as_list(value: any) -> list[any] {
    return value if isinstance(value, list) else [];
}

def _as_ext_set(value: any) -> set[str] {
    out: set[str] = set();
    for item in _as_list(value) {
        text = str(item).strip().lower();
        if text {
            out.add(text if text.startswith('.') else f".{text}");
        }
    }
    return out;
}

def configured_extra_extensions -> set[str] {
    import from jaclang.project.config { get_config }
    config = get_config();
    client_cfg = config.get_plugin_config('client') if config else None;
    raw = _as_dict(client_cfg.get('assets') if client_cfg else None);
    return _as_ext_set(_as_dict(raw.get('extensions')).get('add')) | _as_ext_set(
        raw.get('custom_extensions')
    );
}

def confined_path(root_dir: Path, rel: str) -> (Path | None) {
    try {
        candidate = (root_dir / rel).resolve();
        anchor = root_dir.resolve();
    } except (OSError, RuntimeError, ValueError) {
        return None;
    }
    if candidate != anchor and not candidate.is_relative_to(anchor) {
        return None;
    }
    return candidate;
}

def is_reserved_url(rel: str, prefixes: list[str]) -> bool {
    for prefix in prefixes {
        if prefix.endswith('/') {
            if rel.startswith(prefix) {
                return True;
            }
        } elif rel == prefix or rel.startswith(f"{prefix}/") {
            return True;
        }
    }
    return False;
}

def has_cache_bust(query: str) -> bool {
    if not query {
        return False;
    }
    import from urllib.parse { parse_qs }
    keys = parse_qs(query, keep_blank_values=True).keys();
    return any(key in _CACHE_BUST_KEYS for key in keys);
}

def asset_media_type(file_path: Path) -> str {
    return ASSET_MEDIA_TYPES.get(file_path.suffix.lower(), 'application/octet-stream');
}

def is_content_hashed(name: str) -> bool {
    hit = re.search(_HASHED_TOKEN_RE, name);
    if hit is None {
        return False;
    }
    token = hit.group(1);
    if all(ch in _HEX_DIGITS for ch in token) {
        return True;
    }
    return (
        any(ch.isdigit() for ch in token)
        and any(ch.islower() for ch in token)
        and any(ch.isupper() for ch in token)
    );
}

def resolve_project_root(base_path_dir: (Path | None) = None) -> Path {
    import from jaclang.project.config { find_project_root }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    if base_path_dir is None {
        bp_dir = Jac.get_context().base_path_dir or Jac.get_base_path_dir();
        base_path_dir = Path(bp_dir) if bp_dir else Path.cwd();
    }
    found = find_project_root(base_path_dir);
    if found {
        (project_root, _) = found;
        return project_root;
    }
    return base_path_dir;
}

def default_asset_roots(base_path: Path) -> list[AssetRoot] {
    return [
        AssetRoot(
            path=base_path / '.jac' / 'client' / 'dist',
            mode=AssetRootMode.BUILD_OUTPUT.value,
            flatten=True
        ),
        AssetRoot(
            path=base_path / 'dist', mode=AssetRootMode.BUILD_OUTPUT.value, flatten=True
        ),
        AssetRoot(path=base_path / 'public', mode=AssetRootMode.PUBLIC.value),
        AssetRoot(
            path=base_path / 'assets',
            mode=AssetRootMode.SOURCE_ASSET.value,
            flatten=True
        )
    ];
}
