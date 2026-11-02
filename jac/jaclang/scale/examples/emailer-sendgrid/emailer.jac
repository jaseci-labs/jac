"""Custom SendGrid emailer for the jac-scale example.

Subclasses jaclang.scale.emailer.emailer.Emailer. The factory imports this
module at server startup via `provider = "emailer:SendGridEmailer"` in
jac.toml. The constructor receives the resolved emailer config dict
(everything under [scale.emailer]) plus from_address and enabled.

API key is read from the SENDGRID_API_KEY env var. If unset, sends are
logged and dropped (the server keeps running with email features off).
"""

import base64;
import logging;
import os;
import from jaclang.scale.emailer.emailer { Emailer, EmailAttachment }
import from sendgrid { SendGridAPIClient }
import from sendgrid.helpers.mail {
    Mail,
    Attachment,
    ContentId,
    Disposition,
    FileContent,
    FileName,
    FileType,
    ReplyTo
}

glob _logger = logging.getLogger("sendgrid-emailer");


obj SendGridEmailer(Emailer) {
    # Typed as Any because Jac's checker has no stubs for the sendgrid SDK.
    has _client: any = None;

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
        from_addr: (str | None) = None,
        reply_to: (str | None) = None,
        attachments: (list[EmailAttachment] | None) = None
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
        if reply_to {
            msg.reply_to = ReplyTo(reply_to);
        }
        for att in attachments or [] {
            cid = att.bare_content_id();
            inline = bool(cid and body_html);
            msg.add_attachment(
                Attachment(
                    FileContent(base64.b64encode(att.content).decode('ascii')),
                    FileName(att.filename),
                    FileType(att.media_type()),
                    Disposition('inline' if inline else 'attachment'),
                    ContentId(cid) if inline else None
                )
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
