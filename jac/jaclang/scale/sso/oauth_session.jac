import re;
import json;
import secrets;
import hashlib;
import base64;
import hmac;
import from urllib.parse { urlencode }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.identity.identity_storage { primary_username }
import from jaclang.server.identity.auth_tokens { AuthTokenStore }
import from jaclang.scale.sso.provider { OAuth2CodeProvider, SSOUserInfo }

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
        error: str = "";
}

def challenge_of(verifier: str) -> str {
    return base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()
    ).decode().rstrip(
        "="
    );
}

def complete_identity(
    manager: UserManager, info: SSOUserInfo, platform: str, link_user: str = ""
) -> OAuthLogin {
    external_id = info.external_id;
    login = info.username or platform;
    if not external_id or not login {
        return OAuthLogin(error="SSO did not return a valid identity.");
    }
    existing = manager.get_user_by_sso(platform, external_id);
    user_id = str(existing.get("user_id") or "") if existing else "";
    if link_user {
        if user_id and user_id != link_user {
            return OAuthLogin(
                error="That SSO account is already connected to another account."
            );
        }
        for account in manager.get_sso_accounts(link_user) {
            if account.get("platform") == platform
                and account.get("external_id") != external_id {
                return OAuthLogin(
                    error="This account already has a different SSO account."
                );
            }
        }
        user_id = link_user;
    }
    if not user_id {
        name = platform
            + "_"
            + re.sub(r"[^A-Za-z0-9_]", "_", login)[:24]
            + "_"
            + hashlib.sha256(external_id.encode()).hexdigest()[:10];
        result = manager.create_user(name, secrets.token_urlsafe(48));
        if result.get("error") {
            return OAuthLogin(error="Could not create your account. Please try again.");
        }
        user_id = str(result["user_id"]);
    }
    linked = manager.link_sso_account(user_id, platform, external_id)
        if not existing
        else {};
    if linked.get("error") {
        return OAuthLogin(error="Could not connect that SSO account.");
    }
    user = manager.get_user(user_id) or {};
    if not user
        or user.get("status", "active") != "active"
        or user.get("role") == "system" {
        return OAuthLogin(error="This account cannot sign in.");
    }
    profile = user.get("profile") or {};
    profiles = profile.get("sso") or {};
    profiles[platform] = info.profile_fields();
    profile["sso"] = profiles;
    manager.update_user_fields(user_id, {"profile": profile});
    return OAuthLogin(
        ok=True,
        token=manager.create_jwt_token(user_id),
        username=primary_username(user)
    );
}

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
    ) -> OAuthStart {
        if mode not in ["web", "native"]
            or re.fullmatch(r"[A-Za-z0-9_-]{43}", challenge) is None {
            return OAuthStart(error="Invalid sign-in request.");
        }
        user_id = link_user;
        poll = secrets.token_urlsafe(32) if mode == "native" else "";
        oauth_verifier = secrets.token_urlsafe(48) if mode == "native" else "";
        state = AuthTokenStore.instance().create_token(
            user_id,
            "oauth_session:" + self.platform,
            600,
            json.dumps(
                {
                    "client_id": self.provider.client_id,
                    "redirect_uri": self.provider.redirect_uri,
                    "challenge": challenge,
                    "mode": mode,
                    "client_callback": client_callback,
                    "client_managed": client_managed,
                    "oauth_verifier": oauth_verifier,
                    "poll_hash": AuthTokenStore.hash_token(poll) if poll else ""
                }
            )
        );
        params = {
            "client_id": self.provider.client_id,
            "redirect_uri": self.provider.redirect_uri,
            "response_type": "code",
            "state": state,
            "code_challenge": challenge_of(oauth_verifier)
                if oauth_verifier
                else challenge,
            "code_challenge_method": "S256"
        };
        scope = self.provider.scope();
        if scope {
            params["scope"] = scope;
        }
        params.update(self.provider.extra_authorize_params());
        return OAuthStart(
            ok=True,
            state=state,
            poll=poll,
            url=self.provider.authorize_url() + "?" + urlencode(params)
        );
    }

    def record(state: str) -> dict | None {
        record = AuthTokenStore.instance().peek_token(
            state, "oauth_session:" + self.platform
        );
        if not record {
            return None;
        }
        data = json.loads(record["identity_value"]);
        if data.get("client_id") != self.provider.client_id
            or data.get("redirect_uri") != self.provider.redirect_uri {
            return None;
        }
        return record;
    }

    def callback_mode(state: str) -> str {
        record = self.record(state);
        if not record {
            return "";
        }
        return str(json.loads(record["identity_value"]).get("mode", ""));
    }

    async def finish(code: str, state: str, verifier: str) -> OAuthLogin {
        if re.fullmatch(r"[A-Za-z0-9._~-]{43,128}", verifier) is None {
            return OAuthLogin(error="Invalid sign-in verification.");
        }
        store = AuthTokenStore.instance();
        record = self.record(state);
        if not record
            or json.loads(record["identity_value"]).get("mode") != "web"
            or not hmac.compare_digest(
                str(json.loads(record["identity_value"])["challenge"]),
                challenge_of(verifier)
            ) {
            return OAuthLogin(
                error="Sign-in expired or belongs to another device. Please try again."
            );
        }
        record = store.consume_token(state, "oauth_session:" + self.platform);
        if not record {
            return OAuthLogin(error="This sign-in has already been used.");
        }
        return await self.exchange(code, verifier, str(record.get("user_id") or ""));
    }

    async def exchange(code: str, verifier: str, link_user: str) -> OAuthLogin {
        try {
            payload = await self.provider._exchange_code(code, verifier);
            access = str(payload.get("access_token") or "");
            if not access {
                return OAuthLogin(error="Sign-in was not completed. Please try again.");
            }
            info = await self.provider.fetch_user(access, payload);
            return complete_identity(self.users, info, self.platform, link_user);
        } except Exception {
            return OAuthLogin(
                error="Could not complete SSO sign-in. Please try again."
            );
        }
    }

    async def complete_native(code: str, state: str) -> str {
        store = AuthTokenStore.instance();
        record = self.record(state);
        if not record {
            return "Sign-in expired. Please return to the app and try again.";
        }
        data = json.loads(record["identity_value"]);
        if data.get("mode") != "native" {
            return "Invalid sign-in flow.";
        }
        record = store.consume_token(state, "oauth_session:" + self.platform);
        if not record {
            return "This sign-in has already been used.";
        }
        result = await self.exchange(
            code, str(data["oauth_verifier"]), str(record.get("user_id") or "")
        );
        import from jaclang.server.shared_store { shared_store }
        db = shared_store();
        if db is None {
            return "Could not complete sign-in. Please try again.";
        }
        db.rows(
            "INSERT INTO kv_state (key, value, expires_at) VALUES (:k, :v, now() + interval '2 minutes') ON CONFLICT (key) DO NOTHING",
            {
                "k": "oauth-result:" + self.platform + ":" + str(data["poll_hash"]),
                "v": json.dumps(
                    {
                        "ok": result.ok,
                        "token": result.token,
                        "username": result.username,
                        "error": result.error
                    }
                )
            }
        );
        return "Sign-in completed. Return to the app to continue."
            if result.ok
            else result.error;
    }

    def poll(poll: str) -> OAuthLogin {
        if re.fullmatch(r"[A-Za-z0-9_-]{43}", poll) is None {
            return OAuthLogin(error="Invalid sign-in request.");
        }
        import from jaclang.server.shared_store { shared_store }
        db = shared_store();
        if db is None {
            return OAuthLogin(error="Sign-in is unavailable.");
        }
        rows = db.rows(
            "DELETE FROM kv_state WHERE key = :k AND expires_at > now() RETURNING value",
            {
                "k": "oauth-result:"
                    + self.platform
                    + ":"
                    + AuthTokenStore.hash_token(poll)
            }
        );
        if not rows {
            return OAuthLogin();
        }
        return OAuthLogin(**json.loads(rows[0][0]));
    }
}
