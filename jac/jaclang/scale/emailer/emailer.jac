obj Emailer {
    has config: dict[str, any] = {},
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
