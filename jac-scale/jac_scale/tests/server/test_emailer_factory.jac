"""Unit tests for the EmailerFactory provider resolution + token store."""

import sys;
import from pathlib { Path }
import from typing { Any }
import from jac_scale.abstractions.emailer { Emailer }
import from jac_scale.factories.emailer_factory { create as create_emailer, register }
import from jac_scale.auth_tokens { AuthTokenStore, reset_auth_token_store }


obj _RecordingEmailer(Emailer) {
    has sent: list[dict[str, Any]] = [];

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
        self.sent.append(
            {
                "to": to_addr,
                "subject": subject,
                "body": body_text,
                "from": from_addr or self.from_address
            }
        );
        return True;
    }
}


# =============================================================================
# EmailerFactory: provider resolution
# =============================================================================
test "factory_returns_none_when_provider_unset" {
    cfg = {"provider": "", "from_address": "x@y.z", "smtp": {}};
    assert create_emailer(cfg) is None;
}

test "factory_builds_smtp_provider" {
    import from jac_scale.emailers { SMTPEmailer }
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
    # Stash a class in this test module's globals via sys.modules and import via dotted path.
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
    # _import_dotted raises ImportError, factory swallows it and returns None.
    assert create_emailer(cfg) is None;
}

# =============================================================================
# AuthTokenStore: lifecycle, single-use, expiry
# =============================================================================
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
    # Single-use: second consume returns None.
    assert store.consume_token(raw, "reset") is None;
}

test "auth_tokens_purpose_isolation" {
    reset_auth_token_store();
    store = AuthTokenStore.instance();
    raw = store.create_token(user_id="u2", purpose="reset", ttl_seconds=60);
    # Wrong purpose → not found.
    assert store.consume_token(raw, "verify") is None;
    # Right purpose still works.
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
    # Different purpose for same user, should NOT be revoked.
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
