import from pathlib { Path }

glob SITEMAP_NS: str = "http://www.sitemaps.org/schemas/sitemap/0.9",
     URL_SAFE: str = "/:@!$&'()*+,;=?#%";

def normalized_site_url(site_url: str) -> str;

def _is_enumerable(path: str) -> bool;

def _as_path(item: str) -> str;

def _crawl_prefix(path: str) -> str;

def sitemap_paths(
    routes: list[RouteEntry], exclude: list[str], extra: list[str]
) -> list[str];

def robots_disallows(routes: list[RouteEntry], disallow: list[str]) -> list[str];

def robots_blocks(rule: str, path: str) -> bool;

def crawl_rules(
    routes: list[RouteEntry], exclude: list[str], extra: list[str], disallow: list[str]
) -> tuple[list[str], list[str], list[str]];

def render_sitemap(site_url: str, paths: list[str]) -> str;

def render_robots(site_url: str, disallows: list[str], asset_paths: list[str]) -> str;

def scan_routes(app_root: Path) -> list[RouteEntry];

def clear_seo_files(dist_dir: Path) -> None;

def apply_seo(
    dist_dir: Path,
    seo_config: dict[str, any],
    routes: list[RouteEntry],
    public_dirs: list[Path],
    asset_paths: list[str]
) -> list[str];
