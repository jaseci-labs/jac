def natural_width(lines: list[str]) -> int;


glob _CACHE_WIDTH: dict[str, int] = {},
     _CACHE_CONTENT_REV: dict[str, int] = {},
     _CACHE_STYLE_REV: dict[str, int] = {},
     _CACHE_LINES: dict[str, list[str]] = {};


def _cache_valid(
    cached_width: int,
    cached_content_revision: int,
    cached_style_revision: int,
    width: int,
    content_revision: int,
    style_revision: int,
) -> bool;


def wrapped_lines_at(
    content_lines: list[str],
    content_revision: int,
    style_revision: int,
    id_str: str,
    width: int,
) -> list[str];


def wrapped_height(
    content_lines: list[str],
    content_revision: int,
    style_revision: int,
    id_str: str,
    width: int,
) -> int;


def invalidate_measurement_cache(id_str: str);
