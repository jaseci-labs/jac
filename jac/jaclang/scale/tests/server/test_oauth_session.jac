import asyncio;
import json;
import from urllib.parse { urlparse, parse_qs }
import from unittest.mock { MagicMock, patch, AsyncMock }
import from jaclang.scale.sso.oauth_session {
    OAuthSession,
    challenge_of,
    complete_identity
}
import from jaclang.scale.sso.provider { SSOUserInfo }
import from jaclang.scale.sso.github { GithubSSOProvider }
import from jaclang.server.identity.auth_tokens { AuthTokenStore }
import from jaclang.server.identity.user_manager { SessionGrant }

import from .oauth_fixtures { FakeTokens, fake_users, provider }

test "OAuth state is random scoped and PKCE protected" {
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        session = OAuthSession(
            users=fake_users(), provider=provider(), platform="github"
        );
        verifier = "a" * 64;
        first = session.begin(challenge_of(verifier));
        second = session.begin(challenge_of(verifier));
        assert first.ok and first.state != second.state;
        params = parse_qs(urlparse(first.url).query);
        assert params["state"] == [first.state];
        assert params["code_challenge"] == [challenge_of(verifier)];
        assert params["code_challenge_method"] == ["S256"];
        assert "secret" not in first.url;
        assert session.callback_mode(first.state) == "web";
        other = OAuthSession(
            users=fake_users(),
            provider=GithubSSOProvider(
                client_id="different",
                client_secret="secret",
                redirect_uri="https://example.test/callback"
            ),
            platform="github"
        );
        assert other.callback_mode(first.state) == "";
        assert not session.begin("bad").ok;
    }
}

test "Invalid verifier cannot exchange or consume an OAuth session" {
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        p = provider();
        session = OAuthSession(users=fake_users(), provider=p, platform="github");
        started = session.begin(challenge_of("a" * 64));
        with patch.object(
            GithubSSOProvider, "_exchange_code", new_callable=AsyncMock
        ) as exchange {
            result = asyncio.run(session.finish("code", started.state, "b" * 64));
            assert not result.ok;
            exchange.assert_not_awaited();
            assert session.callback_mode(started.state) == "web";
            assert not asyncio.run(session.finish("code", "expired", "a" * 64)).ok;
        }
    }
}

test "OAuth callback exchanges a code once and forwards PKCE verifier" {
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        session = OAuthSession(
            users=fake_users(), provider=provider(), platform="github"
        );
        started = session.begin(challenge_of("a" * 64));
        with patch.object(
            GithubSSOProvider,
            "_exchange_code",
            new_callable=AsyncMock,
            return_value={"access_token": "provider-token"}
        ) as exchange, patch.object(
            GithubSSOProvider,
            "fetch_user",
            new_callable=AsyncMock,
            return_value=SSOUserInfo(email="", external_id="123", username="alice")
        ) {
            result = asyncio.run(session.finish("code", started.state, "a" * 64));
            assert result.ok and result.token == "session-token";
            exchange.assert_awaited_once_with("code", "a" * 64);
            assert not asyncio.run(session.finish("code", started.state, "a" * 64)).ok;
            assert exchange.await_count == 1;
        }
    }
}

test "SSO uses stable provider IDs and never links by an unverified email" {
    manager = fake_users();
    manager.get_user_by_sso.return_value = {"user_id": "original"};
    info = SSOUserInfo(
        email="changed@example.test", external_id="123", username="renamed"
    );
    result = complete_identity(manager, info, "github");
    assert result.ok;
    manager.create_federated_user.assert_not_called();
    manager.find_user_by_identity.assert_not_called();
    manager.open_session.assert_called_once_with("original", "sso");
    manager = fake_users();
    manager.find_user_by_identity.return_value = {"user_id": "victim"};
    assert complete_identity(manager, info, "github").ok;
    manager.find_user_by_identity.assert_not_called();
    manager.open_session.assert_called_once_with("new-user", "sso");
}

test "a provider-verified email links only to a verified local email" {
    info = SSOUserInfo(
        email="Alice@Corp.Example",
        email_verified=True,
        external_id="123",
        username="alice"
    );
    held = {"type": "email", "value_normalized": "alice@corp.example"};

    manager = fake_users();
    manager.find_user_by_identity.return_value = {
        "user_id": "owner",
        "identities": [{** held, "verified": True}]
    };
    linked = complete_identity(manager, info, "github");
    assert linked.ok and linked.token == "session-token";
    manager.find_user_by_identity.assert_called_once_with("alice@corp.example");
    manager.create_federated_user.assert_not_called();
    manager.link_sso_account.assert_called_once_with("owner", "github", "123");
    manager.open_session.assert_called_once_with("owner", "sso");

    for squatted in [
        [{** held, "verified": False}],
        [{"type": "username", "value_normalized": "alice@corp.example"}]
    ] {
        manager = fake_users();
        manager.find_user_by_identity.return_value = {
            "user_id": "squatter",
            "identities": squatted
        };
        refused = complete_identity(manager, info, "github");
        assert not refused.ok and refused.code == "SSO_EMAIL_IN_USE";
        manager.link_sso_account.assert_not_called();
        manager.create_federated_user.assert_not_called();
        manager.open_session.assert_not_called();
    }

    manager = fake_users();
    created = complete_identity(manager, info, "github");
    assert created.ok;
    identities = manager.create_federated_user.call_args.args[0];
    assert {"type": "email", "value": "Alice@Corp.Example", "verified": True}
        in identities;
    assert [i["type"] for i in identities] == ["username", "email"];
}

test "an SSO login answers the second-factor challenge instead of a session" {
    info = SSOUserInfo(email="", external_id="123", username="alice");
    challenge = {"mfa_required": True, "challenge_token": "c" * 43};
    manager = fake_users();
    manager.get_user_by_sso.return_value = {"user_id": "protected"};
    manager.open_session.return_value = SessionGrant(challenge=challenge);
    result = complete_identity(manager, info, "github");
    assert not result.ok and not result.token;
    assert result.code == "MFA_REQUIRED" and result.challenge == challenge;
    manager.create_jwt_token.assert_not_called();

    manager = fake_users();
    manager.open_session.return_value = SessionGrant(challenge=challenge);
    connected = complete_identity(manager, info, "github", "protected");
    assert connected.ok and not connected.token and not connected.challenge;
    manager.link_sso_account.assert_called_once_with("protected", "github", "123");
}

test "SSO into an account with a real verified factor is challenged, not signed in" {
    # The gate is exercised end to end: a factor enrolled and verified through
    # the real manager, in the real store, seen by the real session open.
    import from tempfile { TemporaryDirectory }
    import from jaclang.scale.tests.scale_test_client { fresh_totp_code }
    import from jaclang.server.identity.config { configure_identity }
    import from jaclang.server.identity.user_manager {
        SecondFactorRequired,
        UserManager
    }
    import from jaclang.server.settings {
        AuthSettings,
        LockoutSettings,
        PasswordSettings
    }
    with TemporaryDirectory() as tmpdir {
        try {
            configure_identity(
                AuthSettings(
                    password=PasswordSettings(hash_cost=10),
                    lockout=LockoutSettings(max_attempts=0)
                ),
                tmpdir
            );
            manager = UserManager(base_path=tmpdir);
            import from uuid { uuid4 }
            tag = uuid4().hex[:10];
            user_id = str(
                manager.create_internal_user("mfa" + tag, "correct horse battery")[
                    "user_id"
                ]
            );
            external = "gh-" + tag;
            assert "error" not in manager.link_sso_account(user_id, "github", external);
            info = SSOUserInfo(email="", external_id=external, username="mfa" + tag);

            before = complete_identity(manager, info, "github");
            assert before.ok and before.token , "no factor yet: SSO signs in";

            used: set[int] = set();
            factors = manager.second_factors();
            enrolled = factors.enroll(
                user_id, "correct horse battery", "", "", "mfa" + tag
            );
            assert enrolled["ok"] , enrolled;
            confirmed = factors.confirm(
                user_id,
                str(enrolled["factor_id"]),
                fresh_totp_code(str(enrolled["secret"]), used)
            );
            assert confirmed["ok"] , confirmed;

            try {
                manager.create_jwt_token(user_id);
                assert False , "a plain token was minted past a verified factor";
            } except SecondFactorRequired {}
            held = complete_identity(manager, info, "github");
            assert not held.ok and not held.token;
            assert held.code == "MFA_REQUIRED";
            challenge = str(held.challenge["challenge_token"]);

            proven = factors.complete_login(
                challenge, fresh_totp_code(str(enrolled["secret"]), used), ""
            );
            assert proven["ok"] , proven;
            assert proven["user_id"] == user_id;
            assert proven["first_method"] == "sso" , (
                "the session must say it began with SSO, not with a password"
            );
            password_first = factors.begin_login(user_id);
            assert factors.complete_login(
                str(password_first["challenge_token"]),
                fresh_totp_code(str(enrolled["secret"]), used),
                ""
            )["first_method"]
                == "pwd";
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "the identifier and registration policy governs accounts SSO creates" {
    import from jaclang.server.identity.config { configure_identity }
    import from jaclang.server.settings {
        AuthSettings,
        EmailSettings,
        IdentifierSettings,
        RegistrationSettings
    }
    bare = SSOUserInfo(email="", external_id="123", username="alice");
    verified = SSOUserInfo(
        email="alice@corp.example",
        email_verified=True,
        external_id="123",
        username="alice"
    );
    try {
        configure_identity(
            AuthSettings(
                identifiers=IdentifierSettings(username="off", email="required")
            ),
            ""
        );
        manager = fake_users();
        refused = complete_identity(manager, bare, "github");
        assert not refused.ok and refused.code == "SSO_EMAIL_REQUIRED";
        manager.create_federated_user.assert_not_called();
        manager = fake_users();
        assert complete_identity(manager, verified, "github").ok;
        assert manager.create_federated_user.call_args.args[0]
            == [{"type": "email", "value": "alice@corp.example", "verified": True}];

        configure_identity(
            AuthSettings(email=EmailSettings(allowed_domains=["corp.example"])), ""
        );
        manager = fake_users();
        outsider = SSOUserInfo(
            email="mallory@other.example",
            email_verified=True,
            external_id="999",
            username="mallory"
        );
        barred = complete_identity(manager, outsider, "google");
        assert not barred.ok and barred.code == "EMAIL_DOMAIN_NOT_ALLOWED";
        manager.create_federated_user.assert_not_called();
        manager.open_session.assert_not_called();
        manager = fake_users();
        assert complete_identity(manager, verified, "google").ok;

        configure_identity(
            AuthSettings(registration=RegistrationSettings(enabled=False)), ""
        );
        manager = fake_users();
        closed = complete_identity(manager, verified, "github");
        assert not closed.ok and closed.code == "REGISTRATION_CLOSED";
        manager.create_federated_user.assert_not_called();
        manager = fake_users();
        manager.get_user_by_sso.return_value = {"user_id": "existing"};
        assert complete_identity(manager, verified, "github").ok;
    } finally {
        configure_identity(AuthSettings(), "");
    }
}

test "SSO linking preserves an existing account and rejects conflicts" {
    info = SSOUserInfo(email="", external_id="123", username="alice");
    manager = fake_users();
    assert complete_identity(manager, info, "github", "current").ok;
    manager.create_federated_user.assert_not_called();
    manager.link_sso_account.assert_called_once_with("current", "github", "123");
    manager = fake_users();
    manager.get_user_by_sso.return_value = {"user_id": "someone-else"};
    assert not complete_identity(manager, info, "github", "current").ok;
    manager.open_session.assert_not_called();
    manager = fake_users();
    manager.get_sso_accounts.return_value = [
        {"platform": "github", "external_id": "456"}
    ];
    assert not complete_identity(manager, info, "github", "current").ok;
    manager.open_session.assert_not_called();
}

test "Native OAuth delivers tokens only to the initiating device once" {
    import from tempfile { mkdtemp }
    import from jaclang.server.identity.user_manager { UserManager }
    import from jaclang.server.shared_store { shared_store }
    manager = UserManager(base_path=mkdtemp());
    db = shared_store();
    assert db is not None;
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        session = OAuthSession(
            users=fake_users(), provider=provider(), platform="github"
        );
        started = session.begin(challenge_of("a" * 64), "native");
        assert started.ok and started.poll and started.poll != started.state;
        assert started.poll not in started.url;
        assert not session.poll(started.poll).ok;
        with patch.object(
            GithubSSOProvider,
            "_exchange_code",
            new_callable=AsyncMock,
            return_value={"access_token": "provider-token"}
        ) as exchange, patch.object(
            GithubSSOProvider,
            "fetch_user",
            new_callable=AsyncMock,
            return_value=SSOUserInfo(email="", external_id="123", username="alice")
        ) {
            message = asyncio.run(session.complete_native("code", started.state));
            assert "session-token" not in message;
            assert "provider-token" not in message;
            assert not session.poll(started.state).ok;
            assert session.poll(started.poll).token == "session-token";
            assert not session.poll(started.poll).ok;
            asyncio.run(session.complete_native("code", started.state));
            assert exchange.await_count == 1;
            expired = session.begin(challenge_of("a" * 64), "native");
            asyncio.run(session.complete_native("code", expired.state));
            db.rows(
                "UPDATE kv_state SET expires_at = now() - interval '1 second' WHERE key = :k",
                {"k": "oauth-result:github:" + AuthTokenStore.hash_token(expired.poll)}
            );
            assert not session.poll(expired.poll).ok;
        }
    }
}

test "Disabled and system identities cannot obtain an SSO session" {
    for fields in [{"status": "disabled"}, {"role": "system"}] {
        manager = fake_users();
        manager.get_user_by_sso.return_value = {"user_id": "blocked"};
        manager.get_user.return_value = fields;
        result = complete_identity(
            manager, SSOUserInfo(email="", external_id="123"), "github"
        );
        assert not result.ok;
        manager.open_session.assert_not_called();
    }
}
