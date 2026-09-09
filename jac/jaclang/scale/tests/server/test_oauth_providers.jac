import asyncio;
import json as json_lib;
import unittest.mock;
import from jaclang.server.serving.datatypes { Request, RedirectResponse }
import from jaclang.scale.sso.google { GoogleSSOProvider }
import from jaclang.scale.sso.apple { AppleSSOProvider }
import from jaclang.scale.sso.github { GithubSSOProvider }
def _callback_request(code: str = "auth-code-123") -> Request {
    import from jaclang.server.serving.datatypes { QueryParams, URL }
    return Request(
        method="GET",
        url=URL(path="/sso/callback", query=f"code={code}"),
        query_params=QueryParams(raw={"code": [code]})
    );
}

"""Stand in for a JSON response from a provider's token or userinfo endpoint."""
obj _OAuthResp {
    has payload: dict,
        status_code: int = 200;

    def json -> any {
        return self.payload;
    }

    def ok -> bool {
        return 200 <= self.status_code < 400;
    }

    def text -> str {
        return json_lib.dumps(self.payload);
    }
}

"""Serve canned JSON per request, in call order."""
def _oauth_responder(payloads: list) -> any {
    seen: dict = {"n": 0};

    async def _fake_arequest(method: str, url: str, **kwargs: any) -> _OAuthResp {
        i = seen["n"];
        seen["n"] = i + 1;
        return _OAuthResp(payload=payloads[min(i, len(payloads) - 1)]);
    }
    return _fake_arequest;
}


test "google sso provider initiate auth" {
    provider = GoogleSSOProvider(
        client_id="id", client_secret="secret", redirect_uri="https://app/cb"
    );
    coro: any = provider.initiate_auth(state="st-1");
    response: any = asyncio.run(coro);
    assert response.status_code == 303;
    location = response.headers.get("Location");
    assert location.startswith("https://accounts.google.com/o/oauth2/v2/auth");
    assert "client_id=id" in location;
    assert "response_type=code" in location;
    assert "state=st-1" in location;
    assert "scope=openid" in location;
}

test "google sso provider handle callback" {
    provider = GoogleSSOProvider(
        client_id="id", client_secret="secret", redirect_uri="https://app/cb"
    );
    responder = _oauth_responder(
        [
            {"access_token": "tok-abc"},
            {
                "sub": "12345",
                "email": "test@example.com",
                "name": "Test User",
                "given_name": "Test",
                "family_name": "User"
            }
        ]
    );
    with unittest.mock.patch("jaclang.scale.sso.provider.arequest", responder), unittest.mock.patch(
        "jaclang.scale.sso.google.arequest", responder
    ) {
        coro: any = provider.handle_callback(_callback_request());
        result: any = asyncio.run(coro);
    }
    assert result.email == "test@example.com";
    assert result.external_id == "12345";
    assert result.display_name == "Test User";
}

test "apple sso provider initiate auth" {
    provider = AppleSSOProvider(
        client_id="id", client_secret="secret", redirect_uri="https://app/cb"
    );
    coro: any = provider.initiate_auth();
    response: any = asyncio.run(coro);
    assert response.status_code == 303;
    location = response.headers.get("Location");
    assert location.startswith("https://appleid.apple.com/auth/authorize");
    # Apple posts the callback as a form, so the mode is requested up front.
    assert "response_mode=form_post" in location;
}

test "apple sso provider handle callback" {
    import from jaclang.server.serving.authcrypt { jwt_encode }
    provider = AppleSSOProvider(
        client_id="id", client_secret="secret", redirect_uri="https://app/cb"
    );
    # Apple carries identity in the id_token rather than a userinfo endpoint.
    id_token = jwt_encode(
        {"sub": "apple_12345", "email": "test@privaterelay.appleid.com"}, "unused"
    );
    responder = _oauth_responder([{"access_token": "tok", "id_token": id_token}]);
    with unittest.mock.patch("jaclang.scale.sso.provider.arequest", responder) {
        coro: any = provider.handle_callback(_callback_request());
        result: any = asyncio.run(coro);
    }
    assert result.email == "test@privaterelay.appleid.com";
    assert result.external_id == "apple_12345";
}

test "github sso provider initiate auth" {
    provider = GithubSSOProvider(
        client_id="id", client_secret="secret", redirect_uri="https://app/cb"
    );
    coro: any = provider.initiate_auth();
    response: any = asyncio.run(coro);
    assert response.status_code == 303;
    location = response.headers.get("Location");
    assert location.startswith("https://github.com/login/oauth/authorize");
    assert "scope=" not in location;
}
