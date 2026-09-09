import asyncio;
import json;
import from urllib.parse { urlparse, parse_qs }
import from unittest.mock { patch, AsyncMock }
import from jaclang.server.serving.datatypes {
    Request,
    QueryParams,
    URL,
    Headers,
    RedirectResponse
}
import from jaclang.server.serving.endpoint { JEndPoint }
import from jaclang.server.server { EndpointHost }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.identity.auth_tokens { AuthTokenStore }
import from jaclang.server.transport { TransportResponse, Meta }
import from jaclang.scale.sso.sso_auth { SSOAuth }
import from jaclang.scale.sso.provider { SSOUserInfo }
import from jaclang.scale.sso.github { GithubSSOProvider }
import from jaclang.scale.sso.google { GoogleSSOProvider }
import from jaclang.scale.sso.apple { AppleSSOProvider }
import from jaclang.scale.server.sso_ext { SSOExtension, resolve_sso_client_redirect }
import from jaclang.scale.shared.utils { is_safe_loopback_redirect }
import from .oauth_fixtures { FakeTokens, fake_users }

obj RecordingHost(EndpointHost) {
    has users: UserManager,
        endpoints: list[JEndPoint] = [];

    has user_manager: UserManager { getter; }

    def identity -> UserManager {
        return self.users;
    }

    def add_endpoint(endpoint: JEndPoint) {
        self.endpoints.append(endpoint);
    }
}

impl RecordingHost.user_manager.getter -> UserManager {
    return self.users;
}

def configured -> SSOAuth {
    return SSOAuth(
        users=fake_users(),
        platforms={
            "github": {"client_id": "id", "client_secret": "secret"},
            "google": {"client_id": "id", "client_secret": "secret"},
            "apple": {"client_id": "id", "client_secret": "secret"}
        }
    );
}

def callback_request(state: str, cookie: str = "") -> Request {
    return Request(
        method="GET",
        url=URL(path="/sso/github/callback"),
        query_params=QueryParams(raw={"state": [state], "code": ["code"]}),
        headers=Headers(raw=[("Cookie", cookie)])
    );
}

test "Configured providers use the configured callback endpoint" {
    auth = configured();
    assert isinstance(auth.get_sso("github"), GithubSSOProvider);
    assert isinstance(auth.get_sso("google"), GoogleSSOProvider);
    assert isinstance(auth.get_sso("apple"), AppleSSOProvider);
    assert auth.get_sso("invalid") is None;
    for platform in ["github", "google", "apple"] {
        p: any = auth.get_sso(platform);
        assert p.redirect_uri.endswith("/sso/" + platform + "/callback");
    }
}

test "Legacy browser initiation binds random state to an HttpOnly cookie" {
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        auth = configured();
        result: any = asyncio.run(
            auth.sso_initiate("github", "login", "http://127.0.0.1:4567/callback")
        );
        assert isinstance(result, RedirectResponse);
        params = parse_qs(urlparse(result.headers.get("location")).query);
        state = params["state"][0];
        assert state != "http://127.0.0.1:4567/callback";
        assert params["code_challenge_method"] == ["S256"];
        assert "HttpOnly" in result.headers.get("set-cookie");
        assert "jac_sso_" + state in result.headers.get("set-cookie");
        record = tokens.peek_token(state, "oauth_session:github");
        assert json.loads(record["identity_value"])["client_callback"]
            == "http://127.0.0.1:4567/callback";
    }
}

test "Legacy browser callback rejects missing state and missing browser binding" {
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        auth = configured();
        with patch.object(
            GithubSSOProvider, "_exchange_code", new_callable=AsyncMock
        ) as exchange {
            assert not asyncio.run(
                auth.sso_callback(callback_request(""), "github")
            ).ok;
            started: any = asyncio.run(auth.sso_initiate("github", "login"));
            state = parse_qs(urlparse(started.headers.get("location")).query)["state"][
                0
            ];
            assert not asyncio.run(
                auth.sso_callback(callback_request(state), "github")
            ).ok;
            exchange.assert_not_awaited();
        }
    }
}

test "Legacy browser callback completes only once with the originating cookie" {
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        auth = configured();
        started: any = asyncio.run(auth.sso_initiate("github", "login"));
        state = parse_qs(urlparse(started.headers.get("location")).query)["state"][0];
        cookie = started.headers.get("set-cookie").split(";")[0];
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
            response = asyncio.run(
                auth.sso_callback(callback_request(state, cookie), "github")
            );
            assert response.ok;
            assert response.data["token"] == "session-token";
            assert not asyncio.run(
                auth.sso_callback(callback_request(state, cookie), "github")
            ).ok;
            assert exchange.await_count == 1;
        }
    }
}

test "SSO rejects invalid platforms operations and unconfigured providers" {
    auth = configured();
    assert not asyncio.run(auth.sso_initiate("invalid", "login")).ok;
    assert not asyncio.run(auth.sso_initiate("github", "invalid")).ok;
    assert not asyncio.run(auth.sso_callback(callback_request(""), "invalid")).ok;
    del auth.platforms["github"];
    assert not asyncio.run(auth.sso_initiate("github", "login")).ok;
    assert not asyncio.run(auth.sso_callback(callback_request(""), "github")).ok;
}

test "GitHub sign-in needs public identity only and no email permission" {
    p = GithubSSOProvider(
        client_id="id", client_secret="secret", redirect_uri="https://app.test/callback"
    );
    assert p.scope() == "";
    with patch.object(
        GithubSSOProvider,
        "_api_get",
        new_callable=AsyncMock,
        return_value={
            "id": 123,
            "login": "alice",
            "name": "Alice",
            "avatar_url": "https://avatars.githubusercontent.com/u/123"
        }
    ) as api {
        info = asyncio.run(p.fetch_user("token", {}));
        assert info.external_id == "123" and info.username == "alice";
        assert info.email == "";
        api.assert_awaited_once_with("/user", "token");
    }
}

test "SSO endpoint registration includes browser and native session APIs" {
    host = RecordingHost(users=fake_users());
    with patch("jaclang.scale.server.sso_ext.SSOAuth", return_value=configured()) {
        SSOExtension().register(host);
    }
    paths = [(e.path, e.method.name) for e in host.endpoints];
    for suffix in ["begin", "finish", "poll"] {
        assert ("/sso/{platform}/" + suffix, "POST") in paths;
    }
    assert ("/sso/{platform}/callback", "GET") in paths;
    assert ("/sso/{platform}/callback", "POST") in paths;
    assert ("/sso/firebase/token", "POST") in paths;
}

test "Client callback destinations are never taken from untrusted OAuth state" {
    fallback_url = "https://app.test/callback";
    assert resolve_sso_client_redirect("https://evil.test/steal", fallback_url)
        == fallback_url;
    assert resolve_sso_client_redirect("http://127.0.0.1:4000/callback", fallback_url)
        == "http://127.0.0.1:4000/callback";
    assert not is_safe_loopback_redirect("http://127.0.0.1.evil.test/callback");
    assert not is_safe_loopback_redirect("javascript:alert(1)");
    tokens: any = FakeTokens();
    with patch.object(AuthTokenStore, "instance", return_value=tokens) {
        auth = configured();
        result: any = asyncio.run(
            auth.sso_initiate("github", "login", "https://evil.test/steal")
        );
        state = parse_qs(urlparse(result.headers.get("location")).query)["state"][0];
        assert json.loads(
            tokens.peek_token(state, "oauth_session:github")["identity_value"]
        )["client_callback"]
            == "";
    }
}

test "is safe loopback redirect truth table" {
    assert is_safe_loopback_redirect("http://127.0.0.1:43117/auth/callback");
    assert is_safe_loopback_redirect("http://localhost:8000/cb");
    assert is_safe_loopback_redirect("https://127.0.0.1/cb");
    assert is_safe_loopback_redirect("http://[::1]:5000/cb");

    assert not is_safe_loopback_redirect("https://evil.com/steal");
    assert not is_safe_loopback_redirect("http://127.0.0.1.evil.com/cb");
    assert not is_safe_loopback_redirect("http://127.0.0.1@evil.com/cb");
    assert not is_safe_loopback_redirect("javascript:alert(1)");
    assert not is_safe_loopback_redirect("file:///etc/passwd");
    assert not is_safe_loopback_redirect("");
    assert not is_safe_loopback_redirect(None);
}
