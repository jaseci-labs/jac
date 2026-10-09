import logging;
import smtplib;
import from email.message { EmailMessage }
import from jaclang.scale.emailer.emailer { Emailer, EmailAttachment }

glob logger = logging.getLogger(__name__);

obj SMTPEmailer(Emailer) {
    has host: str = 'localhost',
        port: int = 25,
        username: str = '',
        password: str = '',
        use_tls: bool = True,
        timeout: float = 10.0;

    def postinit -> None;
    override def send_email(
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None) = None,
        from_addr: (str | None) = None,
        reply_to: (str | None) = None,
        attachments: (list[EmailAttachment] | None) = None
    ) -> bool;

    override def is_ready -> bool;
    def _build_message(
        sender: str,
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None),
        reply_to: (str | None),
        attachments: list[EmailAttachment]
    ) -> EmailMessage;
}
