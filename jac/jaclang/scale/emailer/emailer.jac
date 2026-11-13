import from email { policy as email_policy }

glob DEFAULT_MEDIA_TYPE: str = 'application/octet-stream',
     MEDIA_TYPE_CHARS: str = "!#$%&'*+-.^_`{|}~",
     RESERVED_HEADERS: tuple[str, ...] = (
         'from',
         'to',
         'cc',
         'bcc',
         'subject',
         'reply-to',
         'sender',
         'mime-version',
         'return-path',
         'received',
         'dkim-signature',
         'authentication-results'
     ),
     RESERVED_HEADER_PREFIXES: tuple[str, ...] = ('content-', 'resent-', 'arc-'),
     MAX_HEADER_LINE: int = 998;

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
        attachments: (list[EmailAttachment] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> bool abst;

    def is_ready -> bool;
    def checked_headers(headers: (dict[str, str] | None)) -> dict[str, str];
}
