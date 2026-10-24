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

impl natural_width(lines: list[str]) -> int {
    best = 0;
    for line in lines {
        w = display_width(line);
        if w > best {
            best = w;
        }
    }
    return best;
}


impl _cache_valid(
    cached_width: int,
    cached_content_revision: int,
    cached_style_revision: int,
    width: int,
    content_revision: int,
    style_revision: int,
) -> bool {
    return (
        cached_width == width
        and cached_content_revision == content_revision
        and cached_style_revision == style_revision
    );
}


impl wrapped_lines_at(
    content_lines: list[str],
    content_revision: int,
    style_revision: int,
    id_str: str,
    width: int,
) -> list[str] {
    if width < 1 {
        width = 1;
    }
    cached_width = _CACHE_WIDTH.get(id_str);
    cached_cr = _CACHE_CONTENT_REV.get(id_str, 0);
    cached_sr = _CACHE_STYLE_REV.get(id_str, 0);
    if cached_width is not None {
        cached_lines = _CACHE_LINES.get(id_str);
        if cached_lines is not None
            and _cache_valid(
                cached_width,
                cached_cr,
                cached_sr,
                width,
                content_revision,
                style_revision
            ) {
            return cached_lines;
        }
    }

    wrapped: list[str] = [];
    for line in content_lines {
        joined = wrap_text_joined(line, width);
        wrapped.extend(joined.split("\n"));
    }
    _CACHE_WIDTH[id_str] = width;
    _CACHE_CONTENT_REV[id_str] = content_revision;
    _CACHE_STYLE_REV[id_str] = style_revision;
    _CACHE_LINES[id_str] = wrapped;
    return wrapped;
}


impl wrapped_height(
    content_lines: list[str],
    content_revision: int,
    style_revision: int,
    id_str: str,
    width: int,
) -> int {
    if width < 1 {
        width = 1;
    }
    return len(
        wrapped_lines_at(content_lines, content_revision, style_revision, id_str, width)
    );
}


impl invalidate_measurement_cache(id_str: str) {
    _CACHE_WIDTH.pop(id_str, None);
    _CACHE_CONTENT_REV.pop(id_str, None);
    _CACHE_STYLE_REV.pop(id_str, None);
    _CACHE_LINES.pop(id_str, None);
}
