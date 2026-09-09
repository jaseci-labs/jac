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

test "SSO uses stable provider IDs and never links by matching email" {
    manager = fake_users();
    manager.get_user_by_sso.return_value = {"user_id": "original"};
    info = SSOUserInfo(
        email="changed@example.test", external_id="123", username="renamed"
    );
    result = complete_identity(manager, info, "github");
    assert result.ok;
    manager.create_user.assert_not_called();
    manager.find_user_by_identity.assert_not_called();
    manager.create_jwt_token.assert_called_once_with("original");
    manager = fake_users();
    manager.find_user_by_identity.return_value = {"user_id": "victim"};
    assert complete_identity(manager, info, "github").ok;
    manager.find_user_by_identity.assert_not_called();
    manager.create_jwt_token.assert_called_once_with("new-user");
}

test "SSO linking preserves an existing account and rejects conflicts" {
    info = SSOUserInfo(email="", external_id="123", username="alice");
    manager = fake_users();
    assert complete_identity(manager, info, "github", "current").ok;
    manager.create_user.assert_not_called();
    manager.link_sso_account.assert_called_once_with("current", "github", "123");
    manager = fake_users();
    manager.get_user_by_sso.return_value = {"user_id": "someone-else"};
    assert not complete_identity(manager, info, "github", "current").ok;
    manager.create_jwt_token.assert_not_called();
    manager = fake_users();
    manager.get_sso_accounts.return_value = [
        {"platform": "github", "external_id": "456"}
    ];
    assert not complete_identity(manager, info, "github", "current").ok;
    manager.create_jwt_token.assert_not_called();
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
        manager.create_jwt_token.assert_not_called();
    }
}
