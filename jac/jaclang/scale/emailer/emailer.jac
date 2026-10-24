glob DEFAULT_MEDIA_TYPE: str = 'application/octet-stream',
     MEDIA_TYPE_CHARS: str = "!#$%&'*+-.^_`{|}~";

obj EmailAttachment {
    has filename: str,
        content: bytes,
        mime_type: str = DEFAULT_MEDIA_TYPE,
        content_id: (str | None) = None;

    def media_type -> str;
    def bare_content_id -> str;
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

    def is_ready -> bool;
}
