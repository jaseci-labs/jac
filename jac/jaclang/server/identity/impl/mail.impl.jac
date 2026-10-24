impl MailResult.sent -> bool {
    return self.outcome == MailOutcome.SENT;
}

impl verification_problems(mode: str, emailer: any) -> list[str] {
    if mode == 'none' or IdentityMailer(emailer=emailer).ready() {
        return [];
    }
    problem = f"[serve.auth.email] verification = '{mode}' needs a mail "
    "transport, and [scale.emailer] configures none";
    if mode == 'required' {
        return [problem];
    }
    logger.warning(problem + '; verification mail will not be sent');
    return [];
}

impl mail_body(action: str, link: str, ttl: int, footer: str = '') -> str {
    return (
        f"Hello,\n\nUse the link below to {action}:\n\n{link}\n\n"
        f"This link expires in {ttl // 60} minutes.\n\n"
        f"If you did not request this, you can ignore this message{footer}."
    );
}

impl recovery_email(user: dict[str, any]) -> (dict[str, any] | None) {
    chosen: (dict[str, any] | None) = None;
    for identity in (user.get('identities') or []) {
        if identity.get('type') != 'email' or not identity.get('verified') {
            continue;
        }
        if identity.get('is_recovery') {
            return identity;
        }
        if chosen is None {
            chosen = identity;
        }
    }
    return chosen;
}

impl IdentityMailer.ready -> bool {
    return self.emailer is not None and bool(self.emailer.is_ready());
}

impl IdentityMailer.link(
    user_id: str, purpose: str, address: str, ttl: int, template: str
) -> str {
    store = AuthTokenStore.instance();
    store.revoke_user_tokens(
        user_id, purpose, address if purpose == VERIFY_PURPOSE else None
    );
    token = store.create_token(
        user_id=user_id, purpose=purpose, ttl_seconds=ttl, identity_value=address
    );
    return template.replace('{token}', token) if template else token;
}

impl IdentityMailer.claim(scope: str, actor: str, per_hour: int) -> MailResult | None {
    if not self.ready() {
        return MailResult(outcome=MailOutcome.DISABLED);
    }
    retry = consume_limit(scope, actor, per_hour, MAIL_WINDOW_SECONDS);
    return MailResult(outcome=MailOutcome.LIMITED, retry_after=retry)
        if retry != 0
        else None;
}

impl IdentityMailer.send_verification(
    user_id: str, identity: dict[str, any], source_ip: str = ''
) -> MailResult {
    rules = auth_settings().email;
    address = str(identity.get('value_normalized') or '');
    refused = self.claim(VERIFY_SCOPE, user_id, rules.send_verification_per_hour);
    if refused is not None {
        if refused.outcome == MailOutcome.LIMITED {
            audit(
                'identity_verification.rate_limited',
                user_id=user_id,
                identity_value=address,
                source_ip=source_ip,
                retry_after_seconds=refused.retry_after
            );
        }
        return refused;
    }
    ttl = rules.verify_token_ttl_seconds;
    sent = self.emailer.send_email(
        to_addr=str(identity.get('value_raw') or address),
        subject='Verify your email address',
        body_text=mail_body(
            'verify your email address',
            self.link(user_id, VERIFY_PURPOSE, address, ttl, rules.verify_url_template),
            ttl
        )
    );
    return MailResult(outcome=MailOutcome.SENT if sent else MailOutcome.FAILED);
}

impl IdentityMailer.announce(
    user: dict[str, any], source_ip: str = '', address: str = ''
) {
    if auth_settings().email.verification == 'none' {
        return;
    }
    for identity in (user.get('identities') or []) {
        if identity.get('type') == 'email'
            and not identity.get('verified')
            and (not address or identity.get('value_normalized') == address) {
            self.send_verification(str(user.get('user_id') or ''), identity, source_ip);
        }
    }
}

impl IdentityMailer.send_reset(
    user: dict[str, any], source_ip: str = ''
) -> MailResult {
    rules = auth_settings().email;
    user_id = str(user.get('user_id') or '');
    recipient = recovery_email(user);
    if recipient is None {
        return MailResult(outcome=MailOutcome.DISABLED);
    }
    address = str(recipient.get('value_normalized') or '');
    refused = self.claim(RESET_SCOPE, address, rules.forgot_password_per_hour);
    if refused is not None {
        if refused.outcome == MailOutcome.LIMITED {
            audit(
                'password_reset.rate_limited',
                user_id=user_id,
                identity_value=address,
                source_ip=source_ip,
                retry_after_seconds=refused.retry_after
            );
        }
        return refused;
    }
    ttl = rules.reset_token_ttl_seconds;
    sent = self.emailer.send_email(
        to_addr=str(recipient.get('value_raw') or address),
        subject='Reset your password',
        body_text=mail_body(
            'reset your password',
            self.link(user_id, RESET_PURPOSE, address, ttl, rules.reset_url_template),
            ttl,
            footer=', your password will remain unchanged'
        )
    );
    audit(
        'password_reset.requested',
        user_id=user_id,
        identity_value=address,
        source_ip=source_ip,
        email_sent=bool(sent)
    );
    return MailResult(outcome=MailOutcome.SENT if sent else MailOutcome.FAILED);
}
