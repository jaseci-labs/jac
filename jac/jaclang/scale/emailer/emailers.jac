import logging;
import re;
import smtplib;
import from email.message { EmailMessage }
import from email.policy { EmailPolicy }

glob logger = logging.getLogger(__name__),
     ENCODED_WORD: re.Pattern[str] = re.compile(r"=\?[^?\s]+\?[bBqQ]\?[^?\s]*\?="),
     FOLD_PIECE: re.Pattern[str] = re.compile(r"[ \t]*[^ \t]+");

class AsciiFoldingPolicy(EmailPolicy) {
    def fold(self: AsciiFoldingPolicy, name: str, value: str) -> str;
    def fold_binary(self: AsciiFoldingPolicy, name: str, value: str) -> bytes;
    def _refolded(self: AsciiFoldingPolicy, name: str, value: str, folded: str) -> str;
}

glob MAIL_POLICY: AsciiFoldingPolicy = AsciiFoldingPolicy();

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
        attachments: (list[EmailAttachment] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> bool;

    override def is_ready -> bool;
    def _build_message(
        sender: str,
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None),
        reply_to: (str | None),
        attachments: list[EmailAttachment],
        headers: (dict[str, str] | None) = None
    ) -> EmailMessage;
}
