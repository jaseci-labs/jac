import from pathlib { Path }


glob DEFAULT_ASSET_EXTENSIONS: set[str] = {
         '.png',
         '.jpg',
         '.jpeg',
         '.gif',
         '.webp',
         '.svg',
         '.ico',
         '.woff',
         '.woff2',
         '.ttf',
         '.otf',
         '.eot',
         '.mp4',
         '.webm',
         '.mp3',
         '.wav',
         '.css',
         '.js',
         '.json'
     };


def asset_extensions -> set[str];

def resolve_static_base(base_path: str) -> Path;

def client_dist_index(client_dist: str) -> (Path | None);

def static_roots(
    base_path: str, client_dist: str = ''
) -> tuple[list[Path], list[Path], list[Path]];

def _within_assets(rel: str) -> str;

def find_static_candidate(
    base_path: str, relative_path: str, client_dist: str = ''
) -> (Path | None);

glob ROOT_ASSET_EXTENSIONS: set[str] = DEFAULT_ASSET_EXTENSIONS
         | {'.pdf', '.txt', '.xml'};


def find_root_asset(
    base_path: str, relative_path: str, client_dist: str = ''
) -> (Path | None);

def is_asset_request(
    path: str, cl_route_path: str, reserved_prefixes: (list[str] | None) = None
) -> bool;


def sibling_app_dist(config: any, name: str, base_path: str) -> (Path | None);

def sibling_app_file(dist: Path, rel: str) -> Path;

def sibling_app_names(config: any, base_path: str) -> list[str];
