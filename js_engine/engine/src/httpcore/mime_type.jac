"""HTTP MIME type helpers for js_engine.

Provides a compact extension → MIME lookup table covering the common web types
needed for Phase 6 HTTP server/client work.

Bun reference: `bun/src/http/MimeType.zig`
"""

def _mime_substr(s: str, start: int, end: int) -> str {
    out: str = "";
    i: int = start;
    n: int = len(s);
    if i < 0 {
        i = 0;
    }
    if end > n {
        end = n;
    }
    while i < end {
        out = out + s[i];
        i = i + 1;
    }
    return out;
}

def _mime_norm_ext(ext: str) -> str {
    raw: str = ext.strip().lower();
    if raw == "" {
        return "";
    }
    if raw[0] == "." {
        return raw;
    }
    return "." + raw;
}

def:pub mime_from_extension(ext: str) -> str {
    norm: str = _mime_norm_ext(ext);
    if norm == ".txt" or norm == ".text" {
        return "text/plain";
    }
    if norm == ".html" or norm == ".htm" {
        return "text/html";
    }
    if norm == ".css" {
        return "text/css";
    }
    if norm == ".csv" {
        return "text/csv";
    }
    if norm == ".xml" {
        return "application/xml";
    }
    if norm == ".js" or norm == ".mjs" or norm == ".cjs" {
        return "application/javascript";
    }
    if norm == ".ts" {
        return "application/typescript";
    }
    if norm == ".tsx" {
        return "text/tsx";
    }
    if norm == ".jsx" {
        return "text/jsx";
    }
    if norm == ".json" or norm == ".map" {
        return "application/json";
    }
    if norm == ".pdf" {
        return "application/pdf";
    }
    if norm == ".wasm" {
        return "application/wasm";
    }
    if norm == ".zip" {
        return "application/zip";
    }
    if norm == ".gz" {
        return "application/gzip";
    }
    if norm == ".tar" {
        return "application/x-tar";
    }
    if norm == ".tgz" {
        return "application/gzip";
    }
    if norm == ".bin" {
        return "application/octet-stream";
    }
    if norm == ".svg" {
        return "image/svg+xml";
    }
    if norm == ".png" {
        return "image/png";
    }
    if norm == ".jpg" or norm == ".jpeg" {
        return "image/jpeg";
    }
    if norm == ".gif" {
        return "image/gif";
    }
    if norm == ".webp" {
        return "image/webp";
    }
    if norm == ".ico" {
        return "image/x-icon";
    }
    if norm == ".mp3" {
        return "audio/mpeg";
    }
    if norm == ".mp4" {
        return "video/mp4";
    }
    if norm == ".webm" {
        return "video/webm";
    }
    if norm == ".woff" {
        return "font/woff";
    }
    if norm == ".woff2" {
        return "font/woff2";
    }
    if norm == ".ttf" {
        return "font/ttf";
    }
    if norm == ".otf" {
        return "font/otf";
    }
    return "application/octet-stream";
}

def:pub mime_from_path(path: str) -> str {
    i: int = len(path) - 1;
    dot: int = -1;
    while i >= 0 {
        ch: str = path[i];
        if ch == "." {
            dot = i;
            break;
        }
        if ch == "/" {
            break;
        }
        i = i - 1;
    }
    if dot < 0 {
        return "application/octet-stream";
    }
    return mime_from_extension(_mime_substr(path, dot, len(path)));
}

def:pub mime_is_text(mime: str) -> bool {
    norm: str = mime.strip().lower();
    if norm.startswith("text/") {
        return True;
    }
    if norm.startswith("application/json") {
        return True;
    }
    if norm.startswith("application/javascript") {
        return True;
    }
    if norm.startswith("application/xml") {
        return True;
    }
    if norm.startswith("application/typescript") {
        return True;
    }
    if norm.startswith("application/x-www-form-urlencoded") {
        return True;
    }
    if norm.startswith("image/svg+xml") {
        return True;
    }
    return False;
}

def:pub mime_charset(mime: str) -> str {
    norm: str = mime.strip();
    lower: str = norm.lower();
    needle: str = "; charset=";
    idx: int = lower.find(needle);
    if idx < 0 {
        return "";
    }
    start: int = idx + len(needle);
    return _mime_substr(norm, start, len(norm)).strip();
}
