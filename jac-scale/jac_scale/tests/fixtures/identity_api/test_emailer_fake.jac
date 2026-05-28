"""In-memory fake emailer for tests.

The /user/add-identity and /user/forgot-password flows need a working emailer
to issue verification + reset tokens. This fake collects every send into a
shared module-level list so tests can assert on what was sent (and pull the
token out of the body).

Loaded via `provider = "test_emailer_fake:FakeEmailer"` in jac.toml.
"""
import from typing { Any }
import from jac_scale.abstractions.emailer { Emailer }

# Shared mailbox - tests inspect and clear this between cases.
glob SENT: list[dict[str, Any]] = [];

obj FakeEmailer(Emailer) {
    override def is_ready -> bool {
        return True;
    }

    override def send_email(
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None) = None,
        from_addr: (str | None) = None
    ) -> bool {
        global SENT;
        SENT.append(
            {
                "to": to_addr,
                "subject": subject,
                "body_text": body_text,
                "body_html": body_html,
                "from": from_addr or self.from_address
            }
        );
        return True;
    }
}
