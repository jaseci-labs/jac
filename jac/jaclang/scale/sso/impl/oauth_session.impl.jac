impl holds_verified_email(user: dict[str, any], email: str) -> bool {
    return any(
        identity.get("type") == "email"
            and identity.get("value_normalized") == email
            and identity.get("verified") for identity in (user.get("identities") or [])
    );
}

impl federated_identities(
    info: SSOUserInfo, platform: str
) -> list[dict[str, any]] | OAuthLogin {
    policy = auth_settings();
    email = info.verified_email();
    if not policy.registration.enabled {
        return OAuthLogin(code="REGISTRATION_CLOSED", error="Registration is closed.");
    }
    if email and check_email(email) {
        return OAuthLogin(
            code="EMAIL_DOMAIN_NOT_ALLOWED",
            error="This email domain is not accepted here."
        );
    }
    if policy.identifiers.email == "required" and not email {
        return OAuthLogin(
            code="SSO_EMAIL_REQUIRED",
            error="This provider did not share a verified email address, which an account here needs."
        );
    }
    identities: list[dict[str, any]] = [];
    if policy.identifiers.username != "off" {
        identities.append(
            {
                "type": "username",
                "value": platform
                    + "_"
                    + re.sub(r"[^A-Za-z0-9_]", "_", info.username or platform)[:24]
                    + "_"
                    + hashlib.sha256(info.external_id.encode()).hexdigest()[:10]
            }
        );
    }
    if email and policy.identifiers.email != "off" {
        identities.append(
            {"type": "email", "value": info.email.strip(), "verified": True}
        );
    }
    return identities;
}

impl challenge_of(verifier: str) -> str {
    return base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()
    ).decode().rstrip(
        "="
    );
}

impl complete_identity(
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
    email = info.verified_email();
    holder = manager.find_user_by_identity(email) if email and not user_id else None;
    if holder {
        if not holds_verified_email(holder, email) {
            return OAuthLogin(
                code="SSO_EMAIL_IN_USE",
                error="An account already uses this email address. Sign in with its password, then connect this provider from your account."
            );
        }
        user_id = str(holder.get("user_id") or "");
    }
    if not user_id {
        identities = federated_identities(info, platform);
        if isinstance(identities, OAuthLogin) {
            return identities;
        }
        result = manager.create_federated_user(identities);
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
    user: dict[str, any] = manager.get_user(user_id) or {};
    if not user
        or user.get("status", "active") != "active"
        or user.get("role") == "system" {
        return OAuthLogin(error="This account cannot sign in.");
    }
    profile: any = user.get("profile") or {};
    profiles: any = profile.get("sso") or {};
    profiles[platform] = info.profile_fields();
    profile["sso"] = profiles;
    manager.update_user_fields(user_id, {"profile": profile});
    grant = manager.open_session(user_id, METHOD_FEDERATED);
    if grant.unverified is not None {
        return OAuthLogin(
            code="EMAIL_NOT_VERIFIED", error="Verify your email address to sign in."
        );
    }
    if grant.challenge {
        return OAuthLogin(
            ok=bool(link_user),
            code="MFA_REQUIRED",
            error=""
                if link_user
                else "This account needs its second factor to sign in.",
            challenge={} if link_user else grant.challenge,
            username=primary_username(user)
        );
    }
    return OAuthLogin(ok=True, token=grant.token, username=primary_username(user));
}

impl OAuthSession.begin(
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
        "code_challenge": challenge_of(oauth_verifier) if oauth_verifier else challenge,
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

impl OAuthSession.record(state: str) -> dict[str, any] | None {
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

impl OAuthSession.callback_mode(state: str) -> str {
    record = self.record(state);
    if not record {
        return "";
    }
    return str(json.loads(record["identity_value"]).get("mode", ""));
}

impl OAuthSession.finish(code: str, state: str, verifier: str) -> OAuthLogin {
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

impl OAuthSession.exchange(code: str, verifier: str, link_user: str) -> OAuthLogin {
    try {
        payload = await self.provider._exchange_code(code, verifier);
        access = str(payload.get("access_token") or "");
        if not access {
            return OAuthLogin(error="Sign-in was not completed. Please try again.");
        }
        info = await self.provider.fetch_user(access, payload);
        return complete_identity(self.users, info, self.platform, link_user);
    } except Exception {
        return OAuthLogin(error="Could not complete SSO sign-in. Please try again.");
    }
}

impl OAuthSession.complete_native(code: str, state: str) -> str {
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

    db = shared_store();
    if db is None {
        return "Could not complete sign-in. Please try again.";
    }
    db.rows(
        "INSERT INTO kv_state (key, value, expires_at) VALUES (:k, :v, now() + interval '2 minutes') ON CONFLICT (key) DO NOTHING",
        {
            "k": "oauth-result:" + self.platform + ":" + str(data["poll_hash"]),
            "v": json.dumps(asdict(result))
        }
    );
    return "Sign-in completed. Return to the app to continue."
        if result.ok
        else result.error;
}

impl OAuthSession.poll(poll: str) -> OAuthLogin {
    if re.fullmatch(r"[A-Za-z0-9_-]{43}", poll) is None {
        return OAuthLogin(error="Invalid sign-in request.");
    }

    db = shared_store();
    if db is None {
        return OAuthLogin(error="Sign-in is unavailable.");
    }
    rows = db.rows(
        "DELETE FROM kv_state WHERE key = :k AND expires_at > now() RETURNING value",
        {"k": "oauth-result:" + self.platform + ":" + AuthTokenStore.hash_token(poll)}
    );
    if not rows {
        return OAuthLogin();
    }
    return OAuthLogin(**json.loads(rows[0][0]));
}
