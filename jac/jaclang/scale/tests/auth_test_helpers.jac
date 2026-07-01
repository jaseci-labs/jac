"""Shared HTTP-test helpers for auth flows.

Used by tests that spin up a `jac start` server and hit /user/* endpoints.
Kept in a non-test_ file so pytest does not collect it as a test module.
"""
import requests;
import from typing { Any }

"""Extract the `data` field from a TransportResponse-shaped JSON body.

Falls back to the raw body when no `data` key exists, so callers can use the
same helper for both wrapped and unwrapped responses.
"""
def data(resp: dict[str, Any]) -> Any {
    if isinstance(resp, dict) and "data" in resp {
        return resp["data"];
    }
    return resp;
}

"""Register a username/password user and return a fresh JWT.

Idempotent against repeat registration: a second call with the same username
will get an IDENTITY_TAKEN response from /user/register, which is ignored;
the subsequent /user/login call still returns a token.
"""
def register_and_login(base_url: str, user: str, pwd: str) -> str {
    requests.post(
        f"{base_url}/user/register",
        json={
            "identities": [{"type": "username", "value": user}],
            "credential": {"type": "password", "password": pwd}
        },
        timeout=5
    );
    resp = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": user},
            "credential": {"type": "password", "password": pwd}
        },
        timeout=5
    ).json();
    return data(resp)["token"];
}
