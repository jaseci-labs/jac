"""Base emailer abstraction for jac_scale.

All emailer implementations should inherit from this class. The built-in
SMTPEmailer ships with jac-scale; users can register their own (e.g. a
SendGrid backend) via EmailerFactory.register() or by setting the
[plugins.scale.emailer] provider field in jac.toml to a 'module.path:ClassName'
import string.
"""
import from typing { Any }

"""Base class for all emailer implementations.

Subclasses must implement send_email(). The constructor receives the resolved
emailer config dict (everything under [plugins.scale.emailer]); subclasses
should pull whatever fields they need from it.
"""
obj Emailer {
    has config: dict[str, Any] = {},
        from_address: str = '',
        enabled: bool = True;

    """Send a plain-text (and optionally HTML) email.

    Args:
        to: Recipient email address.
        subject: Subject line.
        body_text: Plain-text body.
        body_html: Optional HTML body.
        from_addr: Override sender address (falls back to self.from_address).

    Returns:
        True on success, False on failure. Implementations should log errors
        rather than raising; callers treat False as a soft failure (e.g. the
        forgot-password endpoint should still respond 200 even if the email
        couldn't be delivered, to avoid leaking account existence).
    """
    def send_email(
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None) = None,
        from_addr: (str | None) = None
    ) -> bool;

    """Return True if the emailer is configured and ready to send mail.

    The default implementation returns self.enabled; subclasses can override
    if they need to test connectivity or credentials.
    """
    def is_ready -> bool {
        return self.enabled;
    }
}
