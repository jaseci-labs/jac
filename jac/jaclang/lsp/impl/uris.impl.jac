"""URI utility implementations."""

impl _normalize_win_path(path: str) -> tuple[str, str] {
    netloc = "";
    if IS_WIN {
        path = path.replace("\\", "/");
    }
    if path[:2] == "//" {
        idx = path.index("/", 2);
        if idx == -1 {
            netloc = path[2:];
        } else {
            netloc = path[2:idx];
            path = path[idx:];
        }
    }
    if not path.startswith("/") {
        path = "/" + path;
    }
    if RE_DRIVE_LETTER_PATH.match(path) {
        path = path[0] + path[1].lower() + path[2:];
    }
    return (path, netloc);
}

"""Convert a filesystem path to a file:// URI."""
impl from_fs_path(path: str) -> Optional[str] {
    try {
        scheme = "file";
        (params, query, fragment) = ("", "", "");
        (path, netloc) = _normalize_win_path(path);
        return _urlunparse((scheme, netloc, path, params, query, fragment));
    } except (AttributeError, TypeError) {
        return None;
    }
}

"""Convert a file:// URI to a filesystem path."""
impl to_fs_path(uri: str) -> Optional[str] {
    try {
        (scheme, netloc, path, _, _, _) = _urlparse(uri);
        if netloc and path and scheme == "file" {
            value = f"//{netloc}{path}";
        } elif RE_DRIVE_LETTER_PATH.match(path) {
            value = path[1].lower() + path[2:];
        } else {
            value = path;
        }
        if IS_WIN {
            value = value.replace("/", "\\");
        }
        return value;
    } except TypeError {
        return None;
    }
}

impl uri_scheme(uri: str) -> Optional[str] {
    try {
        return _urlparse(uri)[0];
    } except (TypeError, IndexError) {
        return None;
    }
}

impl _urlparse(uri: str) -> tuple[str, str, str, str, str, str] {
    (scheme, netloc, path, params, query, fragment) = parse.urlparse(uri);
    return (
        parse.unquote(scheme),
        parse.unquote(netloc),
        parse.unquote(path),
        parse.unquote(params),
        parse.unquote(query),
        parse.unquote(fragment)
    );
}

impl _urlunparse(parts: tuple[str, str, str, str, str, str]) -> str {
    (scheme, netloc, path, params, query, fragment) = parts;
    if RE_DRIVE_LETTER_PATH.match(path) {
        quoted_path = path[:3] + parse.quote(path[3:]);
    } else {
        quoted_path = parse.quote(path);
    }
    return parse.urlunparse(
        (
            parse.quote(scheme),
            parse.quote(netloc),
            quoted_path,
            parse.quote(params),
            parse.quote(query),
            parse.quote(fragment)
        )
    );
}
