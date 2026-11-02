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
