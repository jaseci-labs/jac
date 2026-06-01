"""Built-in emailer implementations for jac-scale.

Currently only SMTPEmailer ships out of the box. Custom backends (SendGrid,
Mailgun, Amazon SES, etc.) live in user code and are registered with the
EmailerFactory (see jac_scale.factories.emailer_factory).
"""
import logging;
import smtplib;
import from email.mime.multipart { MIMEMultipart }
import from email.mime.text { MIMEText }
import from typing { Any }
import from jac_scale.abstractions.emailer { Emailer }

glob logger = logging.getLogger(__name__);

"""SMTP-backed emailer using stdlib smtplib.

Reads its settings from the [plugins.scale.emailer.smtp] sub-section of
jac.toml. Required keys: host, port. Optional: username, password, use_tls,
timeout. The password may be supplied via env var by setting password_env.
"""
obj SMTPEmailer(Emailer) {
    has host: str = 'localhost',
        port: int = 25,
        username: str = '',
        password: str = '',
        use_tls: bool = True,
        timeout: float = 10.0;

    """Read SMTP-specific fields out of self.config['smtp'] after construction."""
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
