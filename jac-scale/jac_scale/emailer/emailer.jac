import from typing { Any }

obj Emailer {
    has config: dict[str, Any] = {},
        from_address: str = '',
        enabled: bool = True;

    def send_email(
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None) = None,
        from_addr: (str | None) = None
    ) -> bool;

    def is_ready -> bool {
        return self.enabled;
    }
}
