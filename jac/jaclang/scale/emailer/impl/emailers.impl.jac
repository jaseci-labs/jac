impl SMTPEmailer.postinit -> None {
    smtp_cfg = self.config.get('smtp', {});
    self.host = smtp_cfg.get('host', self.host);
    self.port = int(smtp_cfg.get('port', self.port));
    self.username = smtp_cfg.get('username', self.username);
    self.password = smtp_cfg.get('password', self.password);
    self.use_tls = bool(smtp_cfg.get('use_tls', self.use_tls));
    self.timeout = float(smtp_cfg.get('timeout', self.timeout));
}

impl SMTPEmailer.is_ready -> bool {
    return self.enabled and bool(self.host) and bool(self.from_address);
}

impl SMTPEmailer.send_email(
    to_addr: str,
    subject: str,
    body_text: str,
    body_html: (str | None) = None,
    from_addr: (str | None) = None,
    reply_to: (str | None) = None,
    attachments: (list[EmailAttachment] | None) = None
) -> bool {
    if not self.enabled {
        logger.warning("SMTPEmailer is disabled, skipping send to %s", to_addr);
        return False;
    }
    sender = from_addr or self.from_address;
    if not sender {
        logger.error("SMTPEmailer: no from_address configured");
        return False;
    }
    try {
        msg = self._build_message(
            sender, to_addr, subject, body_text, body_html, reply_to, attachments or []
        );
        with smtplib.SMTP(self.host, self.port, timeout=self.timeout) as smtp {
            smtp.ehlo();
            if self.use_tls {
                smtp.starttls();
                smtp.ehlo();
            }
            if self.username {
                smtp.login(self.username, self.password);
            }
            smtp.sendmail(sender, [to_addr], msg.as_string());
        }
        logger.debug("SMTPEmailer: sent mail to %s", to_addr);
        return True;
    } except Exception as e {
        logger.error("SMTPEmailer: failed to send to %r: %s", to_addr, e);
        return False;
    }
}

impl SMTPEmailer._build_message(
    sender: str,
    to_addr: str,
    subject: str,
    body_text: str,
    body_html: (str | None),
    reply_to: (str | None),
    attachments: list[EmailAttachment]
) -> EmailMessage {
    msg = EmailMessage();
    msg['Subject'] = subject;
    msg['From'] = sender;
    msg['To'] = to_addr;
    if reply_to {
        msg['Reply-To'] = reply_to;
    }
    msg.set_content(body_text);
    if body_html {
        msg.add_alternative(body_html, subtype='html');
    }
    html_part = msg.get_body(preferencelist=('html', ));
    for att in attachments {
        (maintype, _, subtype) = att.media_type().partition('/');
        cid = att.bare_content_id();
        if cid and html_part is not None {
            html_part.add_related(
                att.content,
                maintype=maintype,
                subtype=subtype,
                cid=f"<{cid}>",
                filename=att.filename,
                disposition='inline'
            );
        } else {
            msg.add_attachment(
                att.content, maintype=maintype, subtype=subtype, filename=att.filename
            );
        }
    }
    return msg;
}
