"""Connected accounts: an SSO provider linked with extra scopes keeps a sealed,
refreshable grant the server can turn into access tokens for its caller."""

import asyncio;
import json;
import time;
import from concurrent.futures { ThreadPoolExecutor }
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

test "a sealed token only opens for the user and provider it was sealed for" {
    context = _grant_context("user-1", "google");
    sealed = seal_secret("token", "key-one", context);
    assert unseal_secret(sealed, "key-one", context) == "token";
    for other in [
        _grant_context("user-2", "google"),
        _grant_context("user-1", "github"),
        ""
    ] {
        try {
            unseal_secret(sealed, "key-one", other);
            assert False , "a token opened outside its owner";
        } except ValueError {}
    }
}

test "a grant keeps earlier tokens only for the same provider account" {
    first = grant_from_tokens(
        "user-1",
        "google",
        "account-a",
        {"access_token": "at-a", "refresh_token": "rt-a", "scope": CAL},
        [CAL]
    );
    same = grant_from_tokens(
        "user-1", "google", "account-a", {"access_token": "at-b"}, [MAIL], first
    );
    assert same["refresh_token"] == first["refresh_token"];
    assert same["connected_at"] == first["connected_at"];
    assert same["scopes"] == sorted([CAL, MAIL]);
    other = grant_from_tokens(
        "user-1",
        "google",
        "account-b",
        {"access_token": "at-c"},
        [MAIL],
        {** first, "connected_at": "2020-01-01T00:00:00+00:00"}
    );
    assert other["refresh_token"] == "";
    assert other["connected_at"] != "2020-01-01T00:00:00+00:00";
    assert other["scopes"] == [MAIL];
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
            assert _grant_secret(user_id, grant, "refresh_token") == "rt-1";
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
            assert _grant_secret(user_id, kept, "refresh_token") == "rt-1";

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
            assert _grant_secret(user_id, rotated, "refresh_token") == "rt-2";

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
                    user_id,
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


def connected_store(tmpdir: str) -> tuple[UserManager, str] {
    configure_identity(AuthSettings(password=PasswordSettings(hash_cost=10)), tmpdir);
    manager = UserManager(base_path=tmpdir);
    user_id = str(
        manager.create_internal_user("conn" + uuid4().hex[:10], "correct horse battery")[
            "user_id"
        ]
    );
    register_sso(
        SSOAuth(
            users=manager,
            platforms={
                "google": {"client_id": "id", "client_secret": "secret", "scopes": CAL}
            }
        )
    );
    connect(manager, user_id, "at-1", "rt-1", -5);
    return (manager, user_id);
}


def connect(
    manager: UserManager, user_id: str, access: str, refresh: str, lifetime: int
) {
    manager.save_oauth_grant(
        user_id,
        grant_from_tokens(
            user_id,
            "google",
            "g-account",
            {"access_token": access, "refresh_token": refresh, "scope": CAL},
            [CAL]
        )
            | {"expires_at": time.time() + lifetime}
    );
}


test "stale writers cannot change or remove a newer grant" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            seen: any = manager.oauth_grant(user_id, "google");
            version = int(seen["version"]);
            assert manager.save_oauth_grant(user_id, seen, version) == version + 1;
            assert manager.save_oauth_grant(user_id, seen, version) == 0;
            assert manager.drop_oauth_grant(user_id, "google", version) is None;
            assert manager.oauth_grant(user_id, "google") is not None;
            assert manager.drop_oauth_grant(user_id, "google", version + 1) is not None;
            assert manager.oauth_grant(user_id, "google") is None;
            assert manager.save_oauth_grant(user_id, seen, version + 1) == 0;
            assert manager.oauth_grant(user_id, "google") is None;
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "a refresh cannot bring back a connection removed while it ran" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            async def disconnect_midway(token: str) -> dict[str, any] {
                assert await disconnect_for(user_id, "google");
                return {"access_token": "at-late", "expires_in": 3600};
            }
            with patch.object(
                GoogleSSOProvider,
                "refresh_grant",
                AsyncMock(side_effect=disconnect_midway)
            ), patch.object(
                GoogleSSOProvider, "revoke_token", AsyncMock(return_value=True)
            ) {
                assert asyncio.run(access_token_for(user_id, "google")) == "";
            }
            assert manager.oauth_grant(user_id, "google") is None;
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "a connection made during a refresh outlives that refresh" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            async def reconnect_midway(token: str) -> dict[str, any] {
                connect(manager, user_id, "at-new", "rt-new", 3600);
                return {"access_token": "at-late", "expires_in": 3600};
            }
            with patch.object(
                GoogleSSOProvider,
                "refresh_grant",
                AsyncMock(side_effect=reconnect_midway)
            ) {
                assert asyncio.run(access_token_for(user_id, "google")) == "at-new";
            }
            kept: any = manager.oauth_grant(user_id, "google");
            assert _grant_secret(user_id, kept, "refresh_token") == "rt-new";

            manager.save_oauth_grant(user_id, {** kept, "expires_at": time.time() - 5});
            async def reconnect_then_refuse(token: str) -> dict[str, any] {
                connect(manager, user_id, "at-newest", "rt-newest", 3600);
                raise GrantRefused("the old token was revoked");
            }
            with patch.object(
                GoogleSSOProvider,
                "refresh_grant",
                AsyncMock(side_effect=reconnect_then_refuse)
            ) {
                assert asyncio.run(access_token_for(user_id, "google")) == "";
            }
            kept = manager.oauth_grant(user_id, "google");
            assert _grant_secret(user_id, kept, "refresh_token") == "rt-newest" , (
                "a refused refresh removed the newer connection"
            );
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "simultaneous callers share one refresh of a single-use token" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            calls: list[str] = [];
            async def single_use(token: str) -> dict[str, any] {
                calls.append(token);
                if len(calls) > 1 {
                    raise GrantRefused("this refresh token was already used");
                }
                await asyncio.sleep(0.05);
                return {
                    "access_token": "at-2",
                    "refresh_token": "rt-2",
                    "expires_in": 3600
                };
            }
            async def callers -> list[str] {
                return list(
                    await asyncio.gather(
                        access_token_for(user_id, "google"),
                        access_token_for(user_id, "google"),
                        access_token_for(user_id, "google")
                    )
                );
            }
            with patch.object(
                GoogleSSOProvider, "refresh_grant", AsyncMock(side_effect=single_use)
            ) {
                assert asyncio.run(callers()) == ["at-2", "at-2", "at-2"];
            }
            assert calls == ["rt-1"];
            kept: any = manager.oauth_grant(user_id, "google");
            assert _grant_secret(user_id, kept, "refresh_token") == "rt-2";
            assert not kept.get("refresh_claimed_until");
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "callers on separate threads and event loops still refresh only once" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            calls: list[str] = [];
            async def single_use(token: str) -> dict[str, any] {
                calls.append(token);
                if len(calls) > 1 {
                    raise GrantRefused("this refresh token was already used");
                }
                await asyncio.sleep(0.2);
                return {
                    "access_token": "at-2",
                    "refresh_token": "rt-2",
                    "expires_in": 3600
                };
            }
            def caller(_: int) -> str {
                return asyncio.run(access_token_for(user_id, "google"));
            }
            with patch.object(
                GoogleSSOProvider, "refresh_grant", AsyncMock(side_effect=single_use)
            ), ThreadPoolExecutor(max_workers=8) as pool {
                tokens = list(pool.map(caller, range(8)));
            }
            assert tokens == ["at-2"] * 8 , tokens;
            assert calls == ["rt-1"];
            kept: any = manager.oauth_grant(user_id, "google");
            assert _grant_secret(user_id, kept, "refresh_token") == "rt-2";
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "a refresh running elsewhere is waited out, and a dead one is taken over" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            refresh: any = AsyncMock(
                return_value={"access_token": "at-2", "expires_in": 3600}
            );
            with patch.object(GoogleSSOProvider, "refresh_grant", refresh) {
                grant: any = manager.oauth_grant(user_id, "google");
                manager.save_oauth_grant(
                    user_id,
                    {
                        ** grant,
                        "expires_at": time.time() + 30,
                        "refresh_claimed_until": time.time() + 30
                    }
                );
                assert asyncio.run(access_token_for(user_id, "google")) == "at-1" , (
                    "a token still in date should serve while another worker refreshes"
                );
                assert refresh.await_count == 0;
                grant = manager.oauth_grant(user_id, "google");
                manager.save_oauth_grant(
                    user_id,
                    {
                        ** grant,
                        "expires_at": time.time() - 5,
                        "refresh_claimed_until": time.time() - 1
                    }
                );
                assert asyncio.run(access_token_for(user_id, "google")) == "at-2";
                assert refresh.await_count == 1;
            }
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "a failed refresh releases its claim and keeps the connection" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            with patch.object(
                GoogleSSOProvider,
                "refresh_grant",
                new_callable=AsyncMock,
                side_effect=RuntimeError("provider unreachable")
            ) {
                try {
                    asyncio.run(access_token_for(user_id, "google"));
                    assert False , "a transient failure read as disconnected";
                } except RuntimeError {}
            }
            kept: any = manager.oauth_grant(user_id, "google");
            assert kept is not None and not kept.get("refresh_claimed_until");
            with patch.object(
                GoogleSSOProvider,
                "refresh_grant",
                new_callable=AsyncMock,
                return_value={"access_token": "at-2", "expires_in": 3600}
            ) {
                assert asyncio.run(access_token_for(user_id, "google")) == "at-2";
            }
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "grants and login credentials cannot overwrite each other" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            storage: any = manager._identity_storage;
            stale = storage._get_credentials(user_id);
            assert all(c.get("type") == "password" for c in stale);

            storage.reset_password(user_id, "a brand new passphrase");
            changed = storage._get_credentials(user_id);
            connect(manager, user_id, "at-2", "rt-2", 3600);
            assert storage._get_credentials(user_id) == changed , (
                "saving a grant touched the login credentials"
            );

            storage._update_credentials(user_id, stale);
            kept: any = manager.oauth_grant(user_id, "google");
            assert _grant_secret(user_id, kept, "refresh_token") == "rt-2" , (
                "writing login credentials touched the grant"
            );
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}

test "unlinking the identity or deleting the user removes the grant" {
    with TemporaryDirectory() as tmpdir {
        try {
            (manager, user_id) = connected_store(tmpdir);
            assert "error"
                not in manager.link_sso_account(user_id, "google", "g-account");
            assert "error" not in manager.unlink_sso_account(user_id, "google");
            assert manager.oauth_grant(user_id, "google") is None;

            connect(manager, user_id, "at-2", "rt-2", 3600);
            assert "error" not in manager.delete_user(user_id);
            assert manager._identity_storage._get_oauth_grants(user_id) == [];
            assert manager.save_oauth_grant(
                user_id, {"platform": "google", "access_token": "", "refresh_token": ""}
            )
                == 0;
            assert manager._identity_storage._get_oauth_grants(user_id) == [];
            manager.close();
        } finally {
            configure_identity(AuthSettings(), "");
        }
    }
}
