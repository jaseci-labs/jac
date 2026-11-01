impl _seal_keys(key_material: str) -> tuple[bytes, bytes] {
    secret = (key_material or signing_secret()).encode('utf-8');
    return (
        hmac.new(secret, b'jac-oauth-grant/enc', hashlib.sha256).digest(),
        hmac.new(secret, b'jac-oauth-grant/mac', hashlib.sha256).digest()
    );
}

impl _keystream(key: bytes, nonce: bytes, length: int) -> bytes {
    out = bytearray();
    counter = 0;
    while len(out) < length {
        out.extend(
            hmac.new(key, nonce + counter.to_bytes(8, 'big'), hashlib.sha256).digest()
        );
        counter += 1;
    }
    return bytes(out[:length]);
}

impl _seal_tag(mac_key: bytes, context: str, nonce: bytes, body: bytes) -> bytes {
    bound = context.encode('utf-8');
    header = b'v1' + len(bound).to_bytes(4, 'big') + bound;
    return hmac.new(mac_key, header + nonce + body, hashlib.sha256).digest();
}

impl seal_secret(plain: str, key_material: str = '', context: str = '') -> str {
    (enc_key, mac_key) = _seal_keys(key_material);
    data = plain.encode('utf-8');
    nonce = secrets.token_bytes(SEAL_NONCE_BYTES);
    stream = _keystream(enc_key, nonce, len(data));
    body = bytes(a ^ b for (a, b) in zip(data, stream));
    tag = _seal_tag(mac_key, context, nonce, body);
    return SEAL_PREFIX + urlsafe_b64encode(nonce + body + tag).decode().rstrip('=');
}

impl unseal_secret(sealed: str, key_material: str = '', context: str = '') -> str {
    if not sealed.startswith(SEAL_PREFIX) {
        raise ValueError('not a sealed secret');
    }
    text = sealed[len(SEAL_PREFIX):];
    try {
        raw = urlsafe_b64decode(text + '=' * (-len(text) % 4));
    } except Exception {
        raise ValueError('sealed secret is not valid base64');
    }
    if len(raw) < SEAL_NONCE_BYTES + SEAL_TAG_BYTES {
        raise ValueError('sealed secret is truncated');
    }
    nonce = raw[:SEAL_NONCE_BYTES];
    body = raw[SEAL_NONCE_BYTES:-SEAL_TAG_BYTES];
    tag = raw[-SEAL_TAG_BYTES:];
    (enc_key, mac_key) = _seal_keys(key_material);
    if not hmac.compare_digest(tag, _seal_tag(mac_key, context, nonce, body)) {
        raise ValueError('sealed secret failed authentication');
    }
    stream = _keystream(enc_key, nonce, len(body));
    return bytes(a ^ b for (a, b) in zip(body, stream)).decode('utf-8');
}

impl _grant_context(user_id: str, platform: str) -> str {
    return f"oauth-grant:{user_id}:{platform}";
}

impl _grant_secret(user_id: str, grant: dict[str, any], field: str) -> str {
    try {
        return unseal_secret(
            str(grant.get(field) or ''),
            context=_grant_context(user_id, str(grant.get('platform') or ''))
        );
    } except ValueError {
        return '';
    }
}

impl grant_from_tokens(
    user_id: str,
    platform: str,
    external_id: str,
    payload: dict[str, any],
    requested: list[str],
    previous: (dict[str, any] | None) = None,
    now: float = 0.0
) -> dict[str, any] {
    moment = now or time.time();
    prior = previous or {};
    if external_id and str(prior.get('external_id') or '') != external_id {
        prior = {};
    }
    context = _grant_context(user_id, platform);
    granted = str(payload.get('scope') or '').replace(',', ' ').split();
    scopes = granted or sorted(set(list(prior.get('scopes') or []) + requested));
    access = str(payload.get('access_token') or '');
    refresh = str(payload.get('refresh_token') or '');
    lifetime = payload.get('expires_in');
    expires_at = 0.0;
    if isinstance(lifetime, (int, float)) and not isinstance(lifetime, bool) {
        expires_at = moment + float(lifetime);
    } elif isinstance(lifetime, str) and lifetime.isdigit() {
        expires_at = moment + float(lifetime);
    }
    stamp = datetime.fromtimestamp(moment, UTC).isoformat();
    return {
        'platform': platform,
        'external_id': external_id or str(prior.get('external_id') or ''),
        'scopes': scopes,
        'access_token': seal_secret(access, context=context) if access else '',
        'refresh_token': seal_secret(refresh, context=context)
            if refresh
            else str(prior.get('refresh_token') or ''),
        'expires_at': expires_at,
        'connected_at': str(prior.get('connected_at') or stamp),
        'refreshed_at': stamp
    };
}

impl connected_account(grant: dict[str, any]) -> ConnectedAccount {
    return ConnectedAccount(
        platform=str(grant.get('platform') or ''),
        external_id=str(grant.get('external_id') or ''),
        scopes=[str(s) for s in (grant.get('scopes') or [])],
        connected_at=str(grant.get('connected_at') or ''),
        refreshable=bool(grant.get('refresh_token'))
    );
}

impl register_sso(auth: SSOAuth) -> None {
    _active['sso'] = auth;
}

impl _refresh_claimed(
    auth: any,
    user_id: str,
    platform: str,
    grant: dict[str, any],
    refresh: str,
    version: int
) -> str {
    provider: any = auth.get_sso(platform);
    now = time.time();
    try {
        payload = await provider.refresh_grant(refresh);
    } except GrantRefused {
        auth.users.drop_oauth_grant(user_id, platform, version);
        return '';
    } except Exception {
        auth.users.save_oauth_grant(
            user_id, {** grant, 'refresh_claimed_until': 0}, version
        );
        raise;
    }
    saved = auth.users.save_oauth_grant(
        user_id,
        grant_from_tokens(
            user_id,
            platform,
            str(grant.get('external_id') or ''),
            payload,
            list(grant.get('scopes') or []),
            previous=grant,
            now=now
        ),
        version
    );
    if not saved {
        return await access_token_for(user_id, platform);
    }
    return str(payload.get('access_token') or '');
}

impl access_token_for(user_id: str, platform: str) -> str {
    auth: any = _active.get('sso');
    if auth is None or not user_id {
        return '';
    }
    deadline = time.time() + REFRESH_LEASE_SECONDS;
    while time.time() < deadline {
        grant = auth.users.oauth_grant(user_id, platform);
        if not grant {
            return '';
        }
        now = time.time();
        expires_at = float(grant.get('expires_at') or 0);
        access = _grant_secret(user_id, grant, 'access_token');
        if access and (expires_at == 0 or expires_at - REFRESH_SKEW_SECONDS > now) {
            return access;
        }
        if float(grant.get('refresh_claimed_until') or 0) > now {
            if access and expires_at > now {
                return access;
            }
            await asyncio.sleep(REFRESH_POLL_SECONDS);
            continue;
        }
        refresh = _grant_secret(user_id, grant, 'refresh_token');
        if not refresh or not isinstance(auth.get_sso(platform), OAuth2CodeProvider) {
            return '';
        }
        claim = {** grant, 'refresh_claimed_until': now + REFRESH_LEASE_SECONDS};
        version = auth.users.save_oauth_grant(user_id, claim, int(grant['version']));
        if version {
            return await _refresh_claimed(
                auth, user_id, platform, claim, refresh, version
            );
        }
    }
    return '';
}

impl connections_for(user_id: str) -> list[ConnectedAccount] {
    auth: any = _active.get('sso');
    if auth is None or not user_id {
        return [];
    }
    return [connected_account(g) for g in auth.users.oauth_grants(user_id)];
}

impl disconnect_for(user_id: str, platform: str) -> bool {
    auth: any = _active.get('sso');
    if auth is None or not user_id {
        return False;
    }
    dropped = auth.users.drop_oauth_grant(user_id, platform);
    if dropped is None {
        return False;
    }
    provider = auth.get_sso(platform);
    if isinstance(provider, OAuth2CodeProvider) {
        for field in ['refresh_token', 'access_token'] {
            token = _grant_secret(user_id, dropped, field);
            if token {
                try {
                    await provider.revoke_token(token);
                } except Exception {}
                break;
            }
        }
    }
    return True;
}

impl sso_access_token(platform: str) -> str {
    return await access_token_for(caller_user_id(), platform);
}

impl sso_connections -> list[ConnectedAccount] {
    return connections_for(caller_user_id());
}

impl sso_disconnect(platform: str) -> bool {
    return await disconnect_for(caller_user_id(), platform);
}
