import logging;
import smtplib;
import from email.mime.multipart { MIMEMultipart }
import from email.mime.text { MIMEText }
import from typing { Any }
import from jac_scale.emailer.emailer { Emailer }

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
        from_addr: (str | None) = None
    ) -> bool;

    override def is_ready -> bool;
}
