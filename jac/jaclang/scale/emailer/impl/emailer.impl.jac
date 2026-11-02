impl EmailAttachment.media_type -> str {
    (maintype, slash, subtype) = self.mime_type.split(';')[0].strip().partition('/');
    valid = bool(slash and maintype and subtype)
        and all(
            [
                ch.isascii() and (ch.isalnum() or ch in MEDIA_TYPE_CHARS)
                for ch in maintype + subtype
            ]
        );
    return f"{maintype}/{subtype}" if valid else DEFAULT_MEDIA_TYPE;
}

impl EmailAttachment.bare_content_id -> str {
    found = (self.content_id or '').strip();
    if found.startswith('<') and found.endswith('>') {
        found = found[1:-1].strip();
    }
    return found;
}

impl Emailer.is_ready -> bool {
    return self.enabled;
}

impl Emailer.checked_headers(headers: (dict[str, str] | None)) -> dict[str, str] {
    checked = dict(headers or {});
    for (name, value) in checked.items() {
        if not name or not all([33 <= ord(ch) <= 126 and ch != ':' for ch in name]) {
            raise ValueError(f"Invalid header name: {name!r}");
        }
        lowered = name.lower();
        if lowered in RESERVED_HEADERS
            or lowered.startswith(RESERVED_HEADER_PREFIXES) {
            raise ValueError(f"Header {name!r} is set by send_email itself");
        }
        if '\r' in value or '\n' in value {
            raise ValueError(f"Header {name!r} has a line break in its value");
        }
        longest = max([0] + [len(word) for word in value.split()]);
        if len(name) + 2 + longest > MAX_HEADER_LINE {
            raise ValueError(f"Header {name!r} cannot fit on one mail line");
        }
    }
    return checked;
}
