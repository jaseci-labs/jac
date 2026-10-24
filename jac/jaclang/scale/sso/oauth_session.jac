import re;
import json;

import secrets;
import hashlib;
import base64;
import hmac;
import from urllib.parse { urlencode }

obj OAuthStart {
    has ok: bool = False,
        url: str = "",
        state: str = "",
        poll: str = "",
        error: str = "";
}

obj OAuthLogin {
    has ok: bool = False,
        token: str = "",
        username: str = "",
        error: str = "",
        code: str = "",
        challenge: dict[str, any] = {};
}

def holds_verified_email(user: dict[str, any], email: str) -> bool;

def federated_identities(
    info: SSOUserInfo, platform: str
) -> list[dict[str, any]] | OAuthLogin;

def challenge_of(verifier: str) -> str;

def complete_identity(
    manager: UserManager, info: SSOUserInfo, platform: str, link_user: str = ""
) -> OAuthLogin;

obj OAuthSession {
    has users: UserManager,
        provider: OAuth2CodeProvider,
        platform: str;

    def begin(
        challenge: str,
        mode: str = "web",
        link_user: str = "",
        client_callback: str = "",
        client_managed: bool = False
    ) -> OAuthStart;

    def record(state: str) -> dict[str, any] | None;
    def callback_mode(state: str) -> str;
    async def finish(code: str, state: str, verifier: str) -> OAuthLogin;
    async def exchange(code: str, verifier: str, link_user: str) -> OAuthLogin;
    async def complete_native(code: str, state: str) -> str;
    def poll(poll: str) -> OAuthLogin;
}
