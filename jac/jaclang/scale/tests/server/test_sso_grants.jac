"""Connected accounts: an SSO provider linked with extra scopes keeps a sealed,
refreshable grant the server can turn into access tokens for its caller."""

import asyncio;
import json;
import time;
import from tempfile { TemporaryDirectory }
import from urllib.parse { urlparse, parse_qs }
import from uuid { uuid4 }
import from unittest.mock { patch, AsyncMock }

glob CAL: str = "https://www.googleapis.com/auth/calendar.readonly",
     MAIL: str = "https://www.googleapis.com/auth/gmail.readonly";


def google -> GoogleSSOProvider {
    return GoogleSSOProvider(
        client_id="id",
        client_secret="secret",
        redirect_uri="https://example.test/sso/google/callback"
    );
}


test "sealed secrets round-trip and refuse tampering or another key" {
    sealed = seal_secret("refresh-token-value", "key-one");
    assert "refresh-token-value" not in sealed;
    assert sealed != seal_secret("refresh-token-value", "key-one");
    assert unseal_secret(sealed, "key-one") == "refresh-token-value";
    tampered = sealed[:-2] + ("A" if sealed[-2] != "A" else "B") + sealed[-1];
    for (text, key) in [
        (tampered, "key-one"),
        (sealed, "key-two"),
        ("refresh-token-value", "key-one"),
        ("v1.", "key-one")
    ] {
        try {
            unseal_secret(text, key);
            assert False , "an unauthenticated secret was unsealed";
        } except ValueError {}
    }
}

test "connecting asks for offline access and the extra scopes only for a signed-in user" {
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        session = OAuthSession(
            users=fake_users(), provider=google(), platform="google"
        );
        challenge = challenge_of("a" * 64);
        assert not session.begin(challenge, scopes=[CAL]).ok;
        started = session.begin(challenge, "web", "user-1", "", True, [CAL]);
        assert started.ok;
        params = parse_qs(urlparse(started.url).query);
        assert params["scope"] == ["openid email profile " + CAL];
        assert params["access_type"] == ["offline"];
        assert params["prompt"] == ["consent"];
        assert params["include_granted_scopes"] == ["true"];
        record = tokens.peek_token(started.state, "oauth_session:google");
        assert json.loads(record["identity_value"])["scopes"] == [CAL];
        plain = parse_qs(urlparse(session.begin(challenge).url).query);
        assert plain["scope"] == ["openid email profile"];
        assert "access_type" not in plain;
    }
    auth = SSOAuth(
        users=fake_users(),
        platforms={
            "google": {
                "client_id": "id",
                "client_secret": "secret",
                "scopes": CAL + " " + MAIL
            },
            "github": {"client_id": "id", "client_secret": "secret", "scopes": ""}
        }
    );
    assert auth.connect_scopes("google", []) == [CAL, MAIL];
    assert auth.connect_scopes("google", [MAIL]) == [MAIL];
    assert auth.connect_scopes("google", [CAL, "https://example.test/other"]) is None;
    assert auth.connect_scopes("github", []) is None;
}

test "a connected account keeps a sealed grant the server refreshes for its caller" {
    with TemporaryDirectory() as tmpdir {
        try {
            configure_identity(
                AuthSettings(password=PasswordSettings(hash_cost=10)), tmpdir
            );
            manager = UserManager(base_path=tmpdir);
            tag = uuid4().hex[:10];
            user_id = str(
                manager.create_internal_user("conn" + tag, "correct horse battery")[
                    "user_id"
                ]
            );
            auth = SSOAuth(
                users=manager,
                platforms={
                    "google": {
                        "client_id": "id",
                        "client_secret": "secret",
                        "scopes": CAL
                    }
                }
            );
            register_sso(auth);
            provider: any = auth.get_sso("google");
            session = OAuthSession(users=manager, provider=provider, platform="google");
            tokens: any = FakeTokens();
            with patch.object(AuthTokenStore, "instance", return_value=tokens) {
                verifier = "v" * 64;
                started = session.begin(
                    challenge_of(verifier), "web", user_id, "", True, [CAL]
                );
                with patch.object(
                    GoogleSSOProvider,
                    "_exchange_code",
                    new_callable=AsyncMock,
                    return_value={
                        "access_token": "at-1",
                        "refresh_token": "rt-1",
                        "expires_in": 3600,
                        "scope": "openid email profile " + CAL
                    }
                ), patch.object(
                    GoogleSSOProvider,
                    "fetch_user",
                    new_callable=AsyncMock,
                    return_value=SSOUserInfo(email="", external_id="g-" + tag)
                ) {
                    result = asyncio.run(
                        session.finish("code", started.state, verifier)
                    );
                }
            }
            assert result.ok and result.connected , result;
            grant: any = manager.oauth_grant(user_id, "google");
            stored = json.dumps(grant);
            assert "at-1" not in stored and "rt-1" not in stored;
            assert unseal_secret(grant["refresh_token"]) == "rt-1";
            assert CAL in grant["scopes"];

            accounts = connections_for(user_id);
            assert [a.platform for a in accounts] == ["google"];
            assert accounts[0].refreshable and accounts[0].external_id == "g-" + tag;
            assert not hasattr(accounts[0], "access_token");

            assert asyncio.run(access_token_for(user_id, "google")) == "at-1";
            assert asyncio.run(sso_access_token("google")) == "" , (
                "a call outside any request has no caller"
            );
            binding = bind_caller_user(user_id);
            try {
                assert asyncio.run(sso_access_token("google")) == "at-1";
            } finally {
                release_caller_user(binding);
            }

            def expire {
                manager.save_oauth_grant(
                    user_id,
                    {
                        ** manager.oauth_grant(user_id, "google"),
                        "expires_at": time.time() - 5
                    }
                );
            }
            expire();
            refresh: any = AsyncMock(
                return_value={"access_token": "at-2", "expires_in": 3600}
            );
            with patch.object(GoogleSSOProvider, "refresh_grant", refresh) {
                assert asyncio.run(access_token_for(user_id, "google")) == "at-2";
                refresh.assert_awaited_once_with("rt-1");
                assert asyncio.run(access_token_for(user_id, "google")) == "at-2";
                assert refresh.await_count == 1 , "a fresh token was refreshed again";
            }
            kept: any = manager.oauth_grant(user_id, "google");
            assert unseal_secret(kept["refresh_token"]) == "rt-1";

            expire();
            with patch.object(
                GoogleSSOProvider,
                "refresh_grant",
                new_callable=AsyncMock,
                return_value={
                    "access_token": "at-3",
                    "refresh_token": "rt-2",
                    "expires_in": 3600
                }
            ) {
                assert asyncio.run(access_token_for(user_id, "google")) == "at-3";
            }
            rotated: any = manager.oauth_grant(user_id, "google");
            assert unseal_secret(rotated["refresh_token"]) == "rt-2";

            revoke: any = AsyncMock(return_value=True);
            with patch.object(GoogleSSOProvider, "revoke_token", revoke) {
                assert asyncio.run(disconnect_for(user_id, "google"));
                revoke.assert_awaited_once_with("rt-2");
                assert not asyncio.run(disconnect_for(user_id, "google"));
            }
            assert manager.oauth_grant(user_id, "google") is None;
            assert connections_for(user_id) == [];

            manager.save_oauth_grant(
                user_id,
                grant_from_tokens(
                    "google",
                    "g-" + tag,
                    {"access_token": "at-4", "refresh_token": "rt-4", "expires_in": 1},
                    [CAL],
                    now=time.time() - 100
                )
            );
            with patch.object(
                GoogleSSOProvider,
                "refresh_grant",
                new_callable=AsyncMock,
                side_effect=GrantRefused("revoked by the user")
            ) {
                assert asyncio.run(access_token_for(user_id, "google")) == "";
            }
            assert manager.oauth_grant(user_id, "google") is None , (
                "a refresh token the provider refused was kept"
            );
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}
