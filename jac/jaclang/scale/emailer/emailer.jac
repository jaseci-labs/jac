glob DEFAULT_MEDIA_TYPE: str = 'application/octet-stream',
     MEDIA_TYPE_CHARS: str = "!#$%&'*+-.^_`{|}~";

obj EmailAttachment {
    has filename: str,
        content: bytes,
        mime_type: str = DEFAULT_MEDIA_TYPE,
        content_id: (str | None) = None;

    def media_type -> str {
        (maintype, slash, subtype) = self.mime_type.split(';')[0].strip().partition(
            '/'
        );
        valid = bool(slash and maintype and subtype)
            and all(
                [
                    ch.isascii() and (ch.isalnum() or ch in MEDIA_TYPE_CHARS)
                    for ch in maintype + subtype
                ]
            );
        return f"{maintype}/{subtype}" if valid else DEFAULT_MEDIA_TYPE;
    }

    def bare_content_id -> str {
        found = (self.content_id or '').strip();
        if found.startswith('<') and found.endswith('>') {
            found = found[1:-1].strip();
        }
        return found;
    }
}

obj Emailer {
    has config: dict[str, any] = {},
        from_address: str = '',
        enabled: bool = True;

    def send_email(
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None) = None,
        from_addr: (str | None) = None,
        reply_to: (str | None) = None,
        attachments: (list[EmailAttachment] | None) = None
    ) -> bool abst;

    def is_ready -> bool {
        return self.enabled;
    }
}
