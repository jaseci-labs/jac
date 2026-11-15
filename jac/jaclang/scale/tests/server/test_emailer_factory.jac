import socketserver;
import sys;
import threading;
import from email { message_from_bytes, message_from_string, policy }
import from email.message { EmailMessage }
import from pathlib { Path }


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
        attachments: (list[EmailAttachment] | None) = None,
        headers: (dict[str, str] | None) = None
    ) -> bool {
        self.sent.append(
            {
                "to": to_addr,
                "subject": subject,
                "body": body_text,
                "body_html": body_html,
                "from": from_addr or self.from_address,
                "reply_to": reply_to,
                "attachments": attachments or [],
                "headers": headers or {}
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

def _local_smtp(port: int) -> SMTPEmailer {
    return SMTPEmailer(
        config={
            "smtp": {
                "host": "127.0.0.1",
                "port": port,
                "use_tls": False,
                "timeout": 2.0
            }
        },
        from_address="noreply@example.com"
    );
}

def _unreachable_smtp -> SMTPEmailer {
    return _local_smtp(1);
}

def _send_to_smtp_sink(
    subject: str, headers: (dict[str, any] | None)
) -> tuple[bool, list[bytes]] {
    received: list[bytes] = [];

    def _serve(handler_self: any) {
        handler_self.wfile.write(b"220 sink\r\n");
        for line in handler_self.rfile {
            verb = line[:4].upper();
            if verb == b"DATA" {
                handler_self.wfile.write(b"354 go\r\n");
                mail = b"";
                for data_line in handler_self.rfile {
                    if data_line == b".\r\n" {
                        break;
                    }
                    mail += data_line;
                }
                received.append(mail);
            }
            handler_self.wfile.write(
                b"221 bye\r\n" if verb == b"QUIT" else b"250 ok\r\n"
            );
        }
    }

    handler_cls = type(
        "_SmtpSink", (socketserver.StreamRequestHandler, ), {"handle": _serve}
    );
    srv = socketserver.ThreadingTCPServer(("127.0.0.1", 0), handler_cls);
    threading.Thread(
        target=srv.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True
    ).start();
    try {
        sent = _local_smtp(srv.server_address[1]).send_email(
            to_addr="user@x.y", subject=subject, body_text="body", headers=headers
        );
    } finally {
        srv.shutdown();
        srv.server_close();
    }
    return (sent, received);
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

test "smtp_custom_header_reaches_the_wire_unencoded_at_any_length" {
    token = "t" * 200;
    long_url = f"<https://app.example/unsubscribe?t={token}>";
    cases = {
        "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
        "X-Short": "<https://app.example/unsubscribe?t=abc>",
        "List-Unsubscribe": long_url,
        "X-Url-And-Mailto": f"<mailto:u@app.example?subject=unsub>, {long_url}",
        "Message-ID": f"<{'m' * 120}@app.example>",
        "X-Padded-Token": f"<https://app.example/u/{'k' * 80}==?list=weekly>",
        "X-Spaced": f"keep   these\truns {'x' * 90}"
    };
    subject = "Résumé " * 40;
    (sent, mails) = _send_to_smtp_sink(subject, cases);
    assert sent and len(mails) == 1;
    head = mails[0].partition(b"\r\n\r\n")[0];
    assert b"\n" not in head.replace(b"\r\n", b"");
    lines = head.split(b"\r\n");
    assert max([len(line) for line in lines]) <= 998;
    unfolded = head.replace(b"\r\n", b"");
    binary_unfolded = _unreachable_smtp()._build_message(
        "noreply@example.com", "user@x.y", subject, "body", None, None, [], cases
    ).as_bytes().split(
        b"\n\n"
    )[0].replace(
        b"\n", b""
    );
    for (name, value) in cases.items() {
        assert f"{name}: {value}".encode() in unfolded , name;
        assert f"{name}: {value}".encode() in binary_unfolded , name;
    }
    long_subject = f"foo   bar\tbaz {'x' * 90}";
    plain_mails = _send_to_smtp_sink(long_subject, None)[1];
    plain_head = plain_mails[0].partition(b"\r\n\r\n")[0];
    assert f"Subject: {long_subject}".encode() in plain_head.replace(b"\r\n", b"");
    encoded_lines = [
        line
        for line in lines
        if b"=?utf-8?" in line
    ];
    assert encoded_lines and max([len(line) for line in encoded_lines]) <= 78;
    assert all(
        [not any([name.encode() in line for name in cases]) for line in encoded_lines]
    );
    read_back = message_from_bytes(mails[0], policy=policy.default);
    assert read_back["Subject"].split() == subject.split();
    assert read_back["From"] == "noreply@example.com";
}

test "smtp_custom_header_cannot_take_over_the_message_and_bad_ones_are_refused" {
    refused = {
        "From": "evil@x.y",
        "FROM": "evil@x.y",
        "To": "evil@x.y",
        "Cc": "other@x.y",
        "Bcc": "hidden@x.y",
        "Subject": "other",
        "Reply-To": "evil@x.y",
        "Sender": "evil@x.y",
        "MIME-Version": "2.0",
        "Content-Type": "text/html",
        "Content-Transfer-Encoding": "base64",
        "content-disposition": "attachment",
        "Resent-From": "evil@x.y",
        "Return-Path": "<evil@x.y>",
        "Received": "from x",
        "DKIM-Signature": "v=1",
        "Authentication-Results": "x; dkim=pass",
        "ARC-Seal": "i=1",
        "": "empty name",
        "From ": "stray space",
        "X-A: v": "colon in name",
        "X-Naïve": "not ascii",
        "X-A\r\nBcc": "evil@x.y",
        "X-Break": "v\r\nBcc: evil@x.y",
        "X-Trailing-Break": "v\n",
        "X-Nul": "a\x00b",
        "X-Form-Feed": "a\x0cb",
        "X-Del": "a\x7fb",
        "X-Unicode-Break": "a b",
        "Date": "not a date",
        "Message-ID": "no brackets here",
        "X-Too-Long": "<" + "t" * 998 + ">"
    };
    bad_sets: list[dict[str, any]] = [
        {name: value} for (name, value) in refused.items()
    ];
    bad_sets += [
        {"List-Unsubscribe": "<a>", "list-unsubscribe": "<b>"},
        {"X-Count": 1},
        {"X-None": None}
    ];
    for bad in bad_sets {
        emailer = _unreachable_smtp();
        raised = False;
        try {
            emailer.checked_headers(bad);
        } except ValueError {
            raised = True;
        }
        assert raised , bad;
        (sent, mails) = _send_to_smtp_sink("Hi", bad);
        assert not sent and mails == [] , bad;
    }
    fine = {
        "Date": "Thu, 01 Jan 2026 00:00:00 +0000",
        "Message-ID": "<a@b.c>",
        "X-Tag": "weekly\ttab",
        "X-Empty": ""
    };
    assert _RecordingEmailer().checked_headers(fine) == fine;
    assert _RecordingEmailer().checked_headers(None) == {};
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
        mailbox = sys.modules[type(emailer).__module__].SENT;
        assert mailbox[-1]["headers"] == {};
        count = len(mailbox);
        for bad in [{"Bcc": "hidden@x.y"}, {"X-Break": "v\r\nBcc: hidden@x.y"}] {
            refused = emailer.send_email(
                to_addr="dst@x.y", subject="s", body_text="b", headers=bad
            );
            assert refused == False and len(mailbox) == count , bad;
        }
        good = {"List-Unsubscribe": "<https://x.y/u>"};
        assert emailer.send_email(
            to_addr="dst@x.y", subject="s", body_text="b", headers=good
        )
            == True;
        assert mailbox[-1]["headers"] == good;
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
