"""Custom SendGrid emailer for the jac-scale example.

Subclasses jaclang.scale.abstractions.emailer.Emailer. The factory imports this
module at server startup via `provider = "emailer:SendGridEmailer"` in
jac.toml. The constructor receives the resolved emailer config dict
(everything under [scale.emailer]) plus from_address and enabled.

API key is read from the SENDGRID_API_KEY env var. If unset, sends are
logged and dropped (the server keeps running with email features off).
"""

import logging;
import os;
import from typing { Any }
import from jaclang.scale.abstractions.emailer { Emailer }
import from sendgrid { SendGridAPIClient }
import from sendgrid.helpers.mail { Mail }

glob _logger = logging.getLogger("sendgrid-emailer");


obj SendGridEmailer(Emailer) {
    # Typed as Any because Jac's checker has no stubs for the sendgrid SDK.
    has _client: Any = None;

    override def postinit {
        api_key = os.environ.get("SENDGRID_API_KEY", "");
        if api_key {
            self._client = SendGridAPIClient(api_key=api_key);
        } else {
            _logger.warning("SENDGRID_API_KEY not set; emails will be dropped");
        }
    }

    override def is_ready -> bool {
        return self.enabled and self._client is not None;
    }

    override def send_email(
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None) = None,
        from_addr: (str | None) = None
    ) -> bool {
        if self._client is None {
            return False;
        }
        sender = from_addr or self.from_address;
        # Built-in handlers currently only send plain text; pass HTML only
        # when a caller actually provides it.
        if body_html {
            msg = Mail(
                from_email=sender,
                to_emails=to_addr,
                subject=subject,
                plain_text_content=body_text,
                html_content=body_html
            );
        } else {
            msg = Mail(
                from_email=sender,
                to_emails=to_addr,
                subject=subject,
                plain_text_content=body_text
            );
        }
        try {
            resp = self._client.send(msg);
            status: int = int(resp.status_code);
            return 200 <= status < 300;
        } except Exception as e {
            _logger.error("SendGrid send failed: %s", e);
            return False;
        }
    }
}
