import sys;
import from email { message_from_string, policy }
import from email.message { EmailMessage }
import from pathlib { Path }
import from jaclang.scale.emailer.emailer { Emailer, EmailAttachment }
import from jaclang.scale.emailer.emailers { SMTPEmailer }
import from jaclang.scale.emailer.factory { create as create_emailer, register }
import from jaclang.server.identity.auth_tokens {
    AuthTokenStore,
    reset_auth_token_store
}


obj _RecordingEmailer(Emailer) {
    has sent: list[dict[str, any]] = [];

    override def is_ready -> bool {
        return True;
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
        self.sent.append(
            {
                "to": to_addr,
                "subject": subject,
                "body": body_text,
                "body_html": body_html,
                "from": from_addr or self.from_address,
                "reply_to": reply_to,
                "attachments": attachments or []
            }
        );
        return True;
    }
}


test "factory_returns_none_when_provider_unset" {
    cfg = {"provider": "", "from_address": "x@y.z", "smtp": {}};
    assert create_emailer(cfg) is None;
}

test "factory_builds_smtp_provider" {
    import from jaclang.scale.emailer.emailers { SMTPEmailer }
    cfg = {
        "provider": "smtp",
        "from_address": "noreply@example.com",
        "smtp": {"host": "smtp.example.com", "port": 587, "use_tls": True}
    };
    emailer = create_emailer(cfg);
    assert emailer is not None;
    assert isinstance(emailer, SMTPEmailer);
    assert emailer.from_address == "noreply@example.com";
    assert emailer.host == "smtp.example.com";
    assert emailer.port == 587;
}

def _smtp_message(
    body_html: (str | None), reply_to: (str | None), attachments: list[EmailAttachment]
) -> EmailMessage {
    # The message SMTPEmailer would send, read back as a mail client reads it.
    emailer = SMTPEmailer(
        config={"smtp": {"host": "smtp.example.com"}},
        from_address="noreply@example.com"
    );
    built = emailer._build_message(
        "noreply@example.com",
        "user@x.y",
        "Your tickets",
        "See attached.",
        body_html,
        reply_to,
        attachments
    );
    return message_from_string(built.as_string(), policy=policy.default);
}

test "smtp_plain_message_is_text_and_html_alternatives" {
    msg = _smtp_message("<p>See attached.</p>", None, []);
    assert msg.get_content_type() == "multipart/alternative";
    assert msg["Reply-To"] is None;
    plain = msg.get_body(preferencelist=("plain", ));
    html = msg.get_body(preferencelist=("html", ));
    assert plain is not None and html is not None;
    assert plain.get_content().strip() == "See attached.";
    assert "<p>See attached.</p>" in html.get_content();
}

test "smtp_message_has_reply_to_and_inline_and_attached_files" {
    msg = _smtp_message(
        '<img src="cid:qr-1">',
        "Box Office <boxoffice@example.com>",
        [
            EmailAttachment(
                filename="qr.png",
                content=b"PNG-BYTES",
                mime_type="image/png",
                content_id="qr-1"
            ),
            EmailAttachment(
                filename="ticket.pdf", content=b"PDF-BYTES", mime_type="application/pdf"
            )
        ]
    );
    assert msg["Reply-To"] == "Box Office <boxoffice@example.com>";
    assert msg.get_content_type() == "multipart/mixed";
    related = msg.get_body(preferencelist=("related", ));
    assert related is not None;
    image = [
        p
        for p in related.iter_parts()
        if p.get_content_type() == "image/png"
    ][0];
    assert image["Content-ID"] == "<qr-1>";
    assert image.get_content() == b"PNG-BYTES";
    attached = list(msg.iter_attachments());
    assert [a.get_filename() for a in attached] == ["ticket.pdf"];
    assert attached[0].get_content() == b"PDF-BYTES";
}

test "smtp_inline_file_without_html_is_attached" {
    msg = _smtp_message(
        None,
        None,
        [
            EmailAttachment(
                filename="qr.png",
                content=b"PNG-BYTES",
                mime_type="image/png",
                content_id="qr-1"
            )
        ]
    );
    assert [a.get_filename() for a in msg.iter_attachments()] == ["qr.png"];
}

def _unreachable_smtp -> SMTPEmailer {
    return SMTPEmailer(
        config={
            "smtp": {"host": "127.0.0.1", "port": 1, "use_tls": False, "timeout": 2.0}
        },
        from_address="noreply@example.com"
    );
}

def _refused(
    to_addr: str, subject: str, reply_to: (str | None), files: list[EmailAttachment]
) {
    emailer = _unreachable_smtp();
    raised = False;
    try {
        emailer._build_message(
            "noreply@example.com", to_addr, subject, "body", None, reply_to, files
        );
    } except ValueError {
        raised = True;
    }
    assert raised , (to_addr, subject, reply_to);
    sent = emailer.send_email(
        to_addr=to_addr,
        subject=subject,
        body_text="body",
        reply_to=reply_to,
        attachments=files
    );
    assert isinstance(sent, bool) and not sent , (to_addr, subject, reply_to);
}

test "smtp_send_returns_false_for_a_header_with_a_line_break" {
    _refused("user@x.y", "Hi\r\nBcc: evil@x.y", None, []);
    _refused("user@x.y\r\nBcc: evil@x.y", "Hi", None, []);
    _refused("user@x.y", "Hi", "ok@x.y\r\nBcc: evil@x.y", []);
    _refused(
        "user@x.y", "Hi", None, [EmailAttachment(filename="a\r\nb.pdf", content=b"PDF")]
    );
    built = _unreachable_smtp()._build_message(
        "noreply@example.com", "user@x.y", "Hi", "body", None, "ok@x.y", []
    );
    assert built["Reply-To"] == "ok@x.y";
}

test "attachment_media_type_is_type_slash_subtype_or_octet_stream" {
    expected = {
        "image/png": "image/png",
        " image/png ": "image/png",
        "text/plain; charset=utf-8": "text/plain",
        "application/vnd.ms-excel": "application/vnd.ms-excel",
        "pdf": "application/octet-stream",
        "": "application/octet-stream",
        "image/": "application/octet-stream",
        "/png": "application/octet-stream",
        "a/b/c": "application/octet-stream",
        "image/p ng": "application/octet-stream",
        "imag\u00e9/png": "application/octet-stream"
    };
    for (given, wanted) in expected.items() {
        found = EmailAttachment(
            filename="f", content=b"x", mime_type=given
        ).media_type();
        assert found == wanted , (given, found);
    }
    msg = _smtp_message(
        None, None, [EmailAttachment(filename="f.pdf", content=b"PDF", mime_type="pdf")]
    );
    attached = list(msg.iter_attachments());
    assert [a.get_content_type() for a in attached] == ["application/octet-stream"];
    assert attached[0].get_content() == b"PDF";
}

test "smtp_content_id_works_with_or_without_angle_brackets" {
    for given in ["qr-1", "<qr-1>", " <qr-1> ", "< qr-1 >"] {
        msg = _smtp_message(
            '<img src="cid:qr-1">',
            None,
            [
                EmailAttachment(
                    filename="qr.png",
                    content=b"PNG",
                    mime_type="image/png",
                    content_id=given
                )
            ]
        );
        related = msg.get_body(preferencelist=("related", ));
        assert related is not None , given;
        images = [
            p
            for p in related.iter_parts()
            if p.get_content_type() == "image/png"
        ];
        assert [p["Content-ID"] for p in images] == ["<qr-1>"] , given;
        assert list(msg.iter_attachments()) == [] , given;
    }
    for blank in ["", "  ", "<>", "< >"] {
        msg = _smtp_message(
            '<img src="cid:qr-1">',
            None,
            [
                EmailAttachment(
                    filename="qr.png",
                    content=b"PNG",
                    mime_type="image/png",
                    content_id=blank
                )
            ]
        );
        assert [a.get_filename() for a in msg.iter_attachments()] == ["qr.png"] , blank;
    }
}

test "factory_uses_registered_name" {
    register("recording", _RecordingEmailer);
    cfg = {"provider": "recording", "from_address": "test@x.y"};
    emailer = create_emailer(cfg);
    assert emailer is not None;
    assert isinstance(emailer, _RecordingEmailer);
    assert emailer.is_ready();
    sent = emailer.send_email(to_addr="user@x.y", subject="hi", body_text="body");
    assert sent == True;
    assert emailer.sent[0]["to"] == "user@x.y";
}

test "factory_imports_dotted_path" {
    fixtures_dir = Path(__file__).parent.parent / "fixtures" / "identity_api";
    sys.path.insert(0, str(fixtures_dir));
    try {
        cfg = {
            "provider": "test_emailer_fake:FakeEmailer",
            "from_address": "x@y.z",
            "smtp": {}
        };
        emailer = create_emailer(cfg);
        assert emailer is not None;
        assert emailer.is_ready();
        ok = emailer.send_email(to_addr="dst@x.y", subject="s", body_text="b");
        assert ok == True;
    } finally {
        if str(fixtures_dir) in sys.path {
            sys.path.remove(str(fixtures_dir));
        }
    }
}

test "factory_returns_none_for_invalid_provider" {
    cfg = {
        "provider": "definitely.not.a.module:NoClass",
        "from_address": "x@y.z",
        "smtp": {}
    };

    assert create_emailer(cfg) is None;
}

test "auth_tokens_create_and_consume_single_use" {
    reset_auth_token_store();
    store = AuthTokenStore.instance();
    raw = store.create_token(
        user_id="u1", purpose="reset", ttl_seconds=60, identity_value="a@b.c"
    );
    assert len(raw) > 16;
    record = store.consume_token(raw, "reset");
    assert record is not None;
    assert record["user_id"] == "u1";
    assert record["identity_value"] == "a@b.c";

    assert store.consume_token(raw, "reset") is None;
}

test "auth_tokens_purpose_isolation" {
    reset_auth_token_store();
    store = AuthTokenStore.instance();
    raw = store.create_token(user_id="u2", purpose="reset", ttl_seconds=60);

    assert store.consume_token(raw, "verify") is None;

    assert store.consume_token(raw, "reset") is not None;
}

test "auth_tokens_expiry" {
    reset_auth_token_store();
    store = AuthTokenStore.instance();
    raw = store.create_token(user_id="u3", purpose="reset", ttl_seconds=-1);
    assert store.consume_token(raw, "reset") is None;
}

test "auth_tokens_revoke_all_for_user" {
    reset_auth_token_store();
    store = AuthTokenStore.instance();
    t1 = store.create_token(user_id="u4", purpose="reset", ttl_seconds=60);
    t2 = store.create_token(user_id="u4", purpose="reset", ttl_seconds=60);

    t3 = store.create_token(user_id="u4", purpose="verify", ttl_seconds=60);
    n = store.revoke_user_tokens("u4", "reset");
    assert n == 2;
    assert store.consume_token(t1, "reset") is None;
    assert store.consume_token(t2, "reset") is None;
    assert store.consume_token(t3, "verify") is not None;
}

test "auth_tokens_hash_is_stable" {
    h1 = AuthTokenStore.hash_token("abc123");
    h2 = AuthTokenStore.hash_token("abc123");
    assert h1 == h2;
    assert h1 != AuthTokenStore.hash_token("abc124");
    assert len(h1) == 64;
}
