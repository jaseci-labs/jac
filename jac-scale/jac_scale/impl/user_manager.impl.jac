impl JacScaleUserManager.postinit -> None {
    sso_config = get_scale_config().get_sso_config();
    for platform in Platforms {
        key = platform.value.lower();
        platform_config = sso_config.get(key, {});
        client_id = platform_config.get('client_id', '');
        client_secret = platform_config.get('client_secret', '');
        if not client_id or not client_secret {
            continue;
        }
        self.SUPPORTED_PLATFORMS[platform.value] = {
            "client_id": client_id,
            "client_secret": client_secret
        };
    }

    db_config = get_scale_config().get_database_config();
    mongodb_uri = db_config.get('mongodb_uri');

    if mongodb_uri is not None {
        import from jac_scale.db { get_mongo_client }
        client = get_mongo_client();
        db = client['jac_db'];
        self._identity_storage = MongoIdentityStorage(users_col=db['users']);
        # LEGACY MIGRATION (removable) — must run before ensure_indexes (old docs have user_id: null)
        self._identity_storage.migrate_legacy_users();
        self._identity_storage.ensure_indexes();
    } else {
        import os;
        # Honor JAC_DATA_PATH so frozen sidecars on read-only system paths
        # (e.g. /usr/lib/<app>/jac for a .deb) write the SQLite store under
        # the user's data dir instead of base_path. Falls back to base_path
        # for dev/source-tree runs where the env var isn't set.
        base_for_data = os.environ.get('JAC_DATA_PATH', self.base_path);
        data_dir = os.path.join(base_for_data, '.jac', 'data');
        os.makedirs(data_dir, exist_ok=True);
        db_path = os.path.join(data_dir, 'users.db');
        self._identity_storage = SqliteIdentityStorage(db_path=db_path);
    }
}

# ============================================================================
# Identity-based User CRUD
# ============================================================================
"""Create a user with identity-based model."""
impl JacScaleUserManager.create_user(
    identities: list[dict[str, Any]],
    credential: dict[str, Any],
    profile: dict[str, Any] | None = None
) -> dict[str, Any] {
    return self._identity_storage.create_user(identities, credential, profile);
}

"""Convenience method for creating internal users (guest, system, admin)."""
impl JacScaleUserManager.create_internal_user(
    username: str, password: str, role: str = 'user'
) -> dict[str, Any] {
    result = self.create_user(
        identities=[{'type': 'username', 'value': username}],
        credential={'type': 'password', 'password': password}
    );
    if result.get('user_id') and role != 'user' {
        self.set_user_role(result['user_id'], role);
    }
    return result;
}

"""Authenticate by any identity value (username or email) + password."""
impl JacScaleUserManager.authenticate(
    identifier: str, password: str
) -> dict[str, Any] | None {
    return self._identity_storage.authenticate(identifier, password);
}

"""Find a user by any identity value."""
impl JacScaleUserManager.find_user_by_identity(value: str) -> dict[str, Any] | None {
    return self._identity_storage.find_user_by_identity(value);
}

"""Check if a user exists by user_id or identity value."""
impl JacScaleUserManager.user_exists(user_id: str) -> bool {
    if self._identity_storage.user_exists_by_id(user_id) {
        return True;
    }
    return self._identity_storage.find_user_by_identity(user_id) is not None;
}

"""Get user by user_id or identity value."""
impl JacScaleUserManager.get_user(user_id: str) -> dict[str, Any] | None {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return user;
}

"""Get root_id by user_id or identity value (for guest/system user fallback)."""
impl JacScaleUserManager.get_root_id(user_id: str) -> str | None {
    # __system__ user gets the super root (full write access to all nodes)
    if user_id == '__system__' {
        return Con.SUPER_ROOT_UUID;
    }
    cache = _root_id_request_cache.get();
    if cache is not None and user_id in cache {
        return cache[user_id];
    }
    result = self._identity_storage.get_root_id(user_id);
    if not result {
        # Fallback: look up by identity value (handles __guest__, etc.)
        user = self._identity_storage.find_user_by_identity(user_id);
        if user {
            result = user.get('root_id');
        }
    }
    if result is not None {
        new_cache = dict(cache) if cache is not None else {};
        new_cache[user_id] = result;
        _root_id_request_cache.set(new_cache);
    }
    return result;
}

"""Update password by user_id.

Revokes all outstanding tokens on success so a compromised password cannot
keep an attacker authenticated beyond the password-change event.
"""
impl JacScaleUserManager.update_password(
    user_id: str, current_password: str, new_password: str
) -> dict[str, str] {
    result = self._identity_storage.update_password(
        user_id, current_password, new_password
    );
    if 'error' not in result {
        self.invalidate_user_tokens(user_id);
    }
    return result;
}

impl JacScaleUserManager.update_profile(
    user_id: str, profile_updates: dict[str, Any]
) -> dict[str, Any] {
    user = self.get_user(user_id);
    if not user {
        return {'error': 'User not found'};
    }
    raw_profile = user.get('profile');
    current_profile: dict[str, Any] = (
        raw_profile if isinstance(raw_profile, dict) else {}
    );
    merged = dict(current_profile);
    for (key, value) in profile_updates.items() {
        merged[key] = value;
    }
    success = self._identity_storage.update_user_fields(user_id, {'profile': merged});
    if not success {
        return {'error': 'Profile update failed'};
    }
    return {'profile': merged};
}

impl JacScaleUserManager.validate_token(token: str) -> str | None {
    return self.validate_jwt_token(token);
}

impl JacScaleUserManager.close -> None { }

"""Revoke all outstanding tokens for a user.

Sets `tokens_valid_from` to now in the user document so that any token
with an older `iat` claim is rejected on the next revocation-cache miss
(within _REVOCATION_CACHE_TTL seconds).  In the same process, decode-cache
entries for this user are immediately evicted via the reverse index so
revocation takes effect without waiting for the cache TTL to expire.

Multi-process deployments: other workers pick up the change on the next
cache miss (within _REVOCATION_CACHE_TTL).  For stricter guarantees, reduce
_REVOCATION_CACHE_TTL or centralise the revocation timestamp in Redis.
"""
impl JacScaleUserManager.invalidate_user_tokens(user_id: str) -> None {
    global _decoded_token_cache,_revocation_ts_cache,_user_token_hashes;

    # Persist revocation boundary so other workers (and restarts) pick it up
    now_unix = time.time();
    self._identity_storage.update_user_fields(user_id, {'tokens_valid_from': now_unix});

    # Eagerly evict this worker's decode-cache entries for this user
    for token_hash in list(_user_token_hashes.get(user_id, set())) {
        _decoded_token_cache.pop(token_hash, None);
    }
    _user_token_hashes.pop(user_id, None);

    # Evict revocation cache so the next validation reads the new boundary
    _revocation_ts_cache.pop(user_id, None);
}

"""Get username from user_id."""
impl JacScaleUserManager.get_username(user_id: str) -> str | None {
    return self._identity_storage.get_username(user_id);
}

# ============================================================================
# JWT Methods — now use user_id as the primary claim
# ============================================================================
impl JacScaleUserManager.create_jwt_token(
    user_id: str, include_role: bool = True
) -> str {
    import uuid;
    now = datetime.now(UTC);
    payload: dict[(str, Any)] = {
        'user_id': user_id,
        'jti': str(uuid.uuid4()),
        'exp': (now + timedelta(days=JWT_EXP_DELTA_DAYS)),
        'iat': now.timestamp()
    };
    if include_role {
        role = self.get_user_role(user_id);
        if role {
            payload['role'] = role;
        }
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM);
}

impl JacScaleUserManager.get_jwt_claims(token: str) -> dict | None {
    try {
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
    } except Exception as e {
        logger.debug(f"Failed to decode JWT token: {str(e)}");
        return None;
    }
}

"""Validate a JWT and return the user_id if the token is authentic and not revoked.

Validation is split into three layers to avoid unnecessary work:

Layer 1 — process-local decode cache (hot path, zero crypto cost):
  SHA-256(raw_token) -> (user_id, monotonic_expiry) with TTL=_TOKEN_CACHE_TTL.
  A hit skips both jwt.decode() and any DB access.

Layer 2 — cryptographic verification (jwt.decode):
  Checks signature and expiry without touching the database.

Layer 3 — revocation check (one DB read per user per _REVOCATION_CACHE_TTL):
  Each user document may carry a `tokens_valid_from` Unix timestamp.  Any token
  whose `iat` claim is older than that timestamp was issued before the last
  revocation event (password change, explicit logout, or account deletion) and
  is rejected.  The per-user `tokens_valid_from` value is cached for
  _REVOCATION_CACHE_TTL seconds so the DB is consulted at most once per user
  per that window, even at high request rates.

Multi-process note: the process-local caches are not shared across workers.
Revocation propagates to other workers within _REVOCATION_CACHE_TTL seconds
(one DB miss per worker per window), and decode-cache entries for the
invalidated user are eagerly evicted in the same worker via invalidate_user_tokens.
"""
impl JacScaleUserManager.validate_jwt_token(token: str) -> str | None {
    global _decoded_token_cache,_revocation_ts_cache,_user_token_hashes;
    now_m = time.monotonic();

    # Layer 1: process-local decode cache — avoids jwt.decode() on repeated hits
    token_hash = hashlib.sha256(token.encode()).hexdigest();
    cached = _decoded_token_cache.get(token_hash);
    if cached is not None {
        # Use index access — tuple-unpack of untyped dict values is not supported
        if now_m < cached[1] {
            return str(cached[0]);
        }
        # Expired entry — evict from both indexes
        del _decoded_token_cache[token_hash];
        hashes = _user_token_hashes.get(str(cached[0]));
        if hashes is not None {
            hashes.discard(token_hash);
        }
    }

    # Layer 2: cryptographic signature + expiry check (no DB)
    try {
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
    } except Exception as e {
        logger.debug(f"JWT validation failed: {e}");
        return None;
    }
    user_id = decoded.get('user_id');
    if not user_id {
        return None;
    }

    # Layer 3: revocation — one DB read per user per _REVOCATION_CACHE_TTL seconds
    iat = float(decoded.get('iat', 0.0));
    rev_entry = _revocation_ts_cache.get(user_id);
    if rev_entry is None or now_m >= rev_entry[1] {
        user_doc = self._identity_storage.get_user_by_id(user_id);
        if user_doc is None {
            # User has been deleted — reject and cache the sentinel so we
            # don't hit the DB on every request for the remaining TTL.
            _revocation_ts_cache[user_id] = (
                float('inf'),
                now_m + _REVOCATION_CACHE_TTL
            );
            return None;
        }
        valid_from_ts = float(user_doc.get('tokens_valid_from', 0.0));
        _revocation_ts_cache[user_id] = (valid_from_ts, now_m + _REVOCATION_CACHE_TTL);
        rev_entry = (valid_from_ts, now_m + _REVOCATION_CACHE_TTL);
    }
    valid_from_ts = rev_entry[0];
    if iat < valid_from_ts {
        logger.debug(
            f"JWT for {user_id} rejected: iat={iat:.3f} predates "
            f"revocation boundary {valid_from_ts:.3f}"
        );
        return None;
    }

    # Populate decode cache and reverse index
    if len(_decoded_token_cache) >= _TOKEN_CACHE_MAX_SIZE {
        _decoded_token_cache.clear();
        _user_token_hashes.clear();
    }
    _decoded_token_cache[token_hash] = (user_id, now_m + _TOKEN_CACHE_TTL);
    _user_token_hashes.setdefault(user_id, set()).add(token_hash);

    return user_id;
}

impl JacScaleUserManager.refresh_jwt_token(token: str) -> str | None {
    try {
        decoded = jwt.decode(
            token, JWT_SECRET, algorithms=[JWT_ALGORITHM], options={"verify_exp": True}
        );
        user_id = decoded.get('user_id');
        return self.create_jwt_token(user_id) if user_id else None;
    } except Exception as e {
        logger.debug(f"Failed to refresh JWT token: {str(e)}");
        return None;
    }
}

# ============================================================================
# SSO Methods
# ============================================================================
impl JacScaleUserManager.get_sso(platform: str) -> SSOProvider | None {
    if platform not in self.SUPPORTED_PLATFORMS {
        return None;
    }
    credentials = self.SUPPORTED_PLATFORMS[platform];
    redirect_uri = f"{SSO_HOST}/sso/{platform}/callback";
    if platform == Platforms.GOOGLE.value {
        import from jac_scale.sso.google { GoogleSSOProvider }
        return GoogleSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    }
    if platform == Platforms.APPLE.value {
        import from jac_scale.sso.apple { AppleSSOProvider }
        return AppleSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    }
    if platform == Platforms.GITHUB.value {
        import from jac_scale.sso.github { GithubSSOProvider }
        return GithubSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    }
    return None;
}

impl JacScaleUserManager.sso_initiate(
    platform: str, operation: str
) -> Response | TransportResponse {
    if platform not in [p.value for p in Platforms] {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    if platform not in self.SUPPORTED_PLATFORMS {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured. Please set SSO_{platform.upper()}_CLIENT_ID and SSO_{platform.upper()}_CLIENT_SECRET environment variables.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    if operation not in [o.value for o in Operations] {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=f"Invalid operation '{operation}'. Must be 'login' or 'register'",
            meta=Meta(extra={'http_status': 400})
        );
    }
    sso = self.get_sso(platform);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    return await sso.initiate_auth();
}

impl JacScaleUserManager.sso_callback(
    request: Request, platform: str
) -> TransportResponse {
    import from jaclang.runtimelib.server { JsonValue }
    if platform not in [p.value for p in Platforms] {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    if platform not in self.SUPPORTED_PLATFORMS {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    sso = self.get_sso(platform);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    try {
        user_info = await sso.handle_callback(request);
        email = user_info.email;
        if not email {
            return TransportResponse.fail(
                code='EMAIL_MISSING',
                message=f"Email not provided by {platform}",
                meta=Meta(extra={'http_status': 400})
            );
        }
        external_id = user_info.external_id;
        sso_fields = user_info.profile_fields();
        existing = self.find_user_by_identity(email);
        if existing {
            user_id = existing.get('user_id', '');
            # Link SSO identity if not already linked
            self.link_sso_account(user_id, platform, external_id);
            # Refresh profile.sso.<platform> from the latest provider data so
            # display_name/picture stay current. Only the SSO namespace is
            # touched — developer-set profile fields are untouched.
            if sso_fields {
                raw_profile = existing.get('profile') if existing else None;
                current_profile: dict[str, Any] = (
                    raw_profile if isinstance(raw_profile, dict) else {}
                );
                # Defensive: legacy users from before reserved-key enforcement
                # may have a non-dict at profile.sso. Treat as empty rather
                # than crashing on dict-style assignment below.
                raw_sso = current_profile.get('sso');
                current_sso: dict[str, Any] = (
                    raw_sso if isinstance(raw_sso, dict) else {}
                );
                current_sso[platform] = sso_fields;
                current_profile['sso'] = current_sso;
                self._identity_storage.update_user_fields(
                    user_id, {'profile': current_profile}
                );
            }
            token = self.create_jwt_token(user_id);
            return TransportResponse.success(
                data={
                    'message': 'Login successful',
                    'user_id': user_id,
                    'token': token,
                    'platform': platform,
                    'root_id': existing.get('root_id', '')
                },
                meta=Meta(extra={'http_status': 200})
            );
        }
        # Create user with verified email identity (provider already verified it)
        sso_profile = {'sso': {platform: sso_fields}} if sso_fields else None;
        result = self.create_user(
            identities=[{'type': 'email', 'value': email, 'verified': True}],
            credential={'type': 'password', 'password': generate_random_password()},
            profile=sso_profile
        );
        if 'error' in result {
            return TransportResponse.fail(
                code='USER_CREATION_FAILED',
                message=result.get('error', 'User creation failed'),
                meta=Meta(extra={'http_status': 400})
            );
        }
        user_id = result.get('user_id', '');
        # Link SSO identity to the new user
        self.link_sso_account(user_id, platform, external_id);
        result['token'] = self.create_jwt_token(user_id);
        result['platform'] = platform;
        return TransportResponse.success(
            data=result, meta=Meta(extra={'http_status': 201})
        );
    } except Exception as e {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=f"Authentication failed: {str(e)}",
            meta=Meta(extra={'http_status': 500})
        );
    }
}

# ============================================================================
# SSO Account Linking
# ============================================================================
impl JacScaleUserManager.link_sso_account(
    user_id: str, platform: str, external_id: str
) -> dict[str, str] {
    return self._identity_storage.link_sso_account(user_id, platform, external_id);
}

impl JacScaleUserManager.unlink_sso_account(
    user_id: str, platform: str
) -> dict[str, str] {
    return self._identity_storage.unlink_sso_account(user_id, platform);
}

impl JacScaleUserManager.get_sso_accounts(user_id: str) -> list[dict[str, str]] {
    return self._identity_storage.get_sso_accounts(user_id);
}

impl JacScaleUserManager.get_user_by_sso(
    platform: str, external_id: str
) -> dict[str, str] | None {
    return self._identity_storage.get_user_by_sso(platform, external_id);
}

# ============================================================================
# User Role and Admin Management
# ============================================================================
impl JacScaleUserManager.get_user_role(user_id: str) -> str | None {
    role = self._identity_storage.get_user_role(user_id);
    if role is None {
        # Fallback: resolve by identity value (admin portal passes username)
        user = self._identity_storage.find_user_by_identity(user_id);
        if user {
            return user.get('role', 'user');
        }
    }
    return role;
}

impl JacScaleUserManager.set_user_role(user_id: str, role: str) -> dict[str, str] {
    valid_roles = [r.value for r in UserRole];
    if role not in valid_roles {
        return {'error': f"Invalid role. Must be one of: {', '.join(valid_roles)}"};
    }
    success = self._identity_storage.set_user_role(user_id, role);
    if not success {
        return {'error': 'User not found'};
    }
    return {'message': f"Role updated to '{role}'", 'user_id': user_id, 'role': role};
}

impl JacScaleUserManager.is_admin(user_id: str) -> bool {
    return self.get_user_role(user_id) == 'admin';
}

"""Check if user needs to reset password."""
impl JacScaleUserManager.requires_password_reset(user_id: str) -> bool {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return bool(user.get('requires_password_reset', False)) if user else False;
}

"""Set requires_password_reset flag."""
impl JacScaleUserManager.set_requires_password_reset(
    user_id: str, requires_reset: bool
) -> dict[str, str] {
    success = self._identity_storage.update_user_fields(
        user_id, {'requires_password_reset': requires_reset}
    );
    if not success {
        return {'error': 'User not found'};
    }
    return {'message': 'Password reset requirement updated', 'user_id': user_id};
}

"""Check if password is required for user."""
impl JacScaleUserManager.is_password_required(user_id: str) -> bool {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return True if not user else bool(user.get('is_password_required', True));
}

impl JacScaleUserManager.list_all_users(
    limit: int = 100, offset: int = 0
) -> list[dict[str, Any]] {
    return self._identity_storage.list_all_users(limit, offset);
}

impl JacScaleUserManager.delete_user(user_id: str) -> dict[str, str] {
    if user_id == self.ADMIN_USER_ID {
        return {'error': 'Cannot delete the bootstrap admin account'};
    }
    user = self._identity_storage.get_user_by_id(user_id);
    if user is None {
        return {'error': 'User not found'};
    }
    if user.get('role') == UserRole.SYSTEM.value {
        return {'error': 'Cannot delete system account'};
    }
    for identity in user.get('identities', []) {
        if identity.get('value_normalized') == Con.GUEST.value {
            return {'error': 'Cannot delete guest account'};
        }
    }
    self._identity_storage.delete_user(user_id);
    # Eager eviction: bust this worker's caches immediately so in-flight
    # requests don't see a valid token for a user that no longer exists.
    self.invalidate_user_tokens(user_id);
    return {'message': 'User deleted successfully', 'user_id': user_id};
}

impl JacScaleUserManager.bootstrap_admin_user -> dict[str, str] {
    admin_config = get_scale_config().get_admin_config();
    if not admin_config.get('enabled', True) {
        return {'message': 'Admin portal is disabled'};
    }
    admin_username = admin_config.get('username', 'admin');
    default_password = admin_config.get('default_password', 'changeme');

    existing = self.find_user_by_identity(admin_username);
    if existing {
        user_id = existing.get('user_id', '');
        if self.get_user_role(user_id) != 'admin' {
            self.set_user_role(user_id, 'admin');
            logger.info(f"Existing user '{admin_username}' promoted to admin role");
        }
        return {'message': 'Admin user already exists', 'username': admin_username};
    }

    result = self.create_internal_user(admin_username, default_password);
    if 'error' in result {
        return result;
    }
    user_id = result.get('user_id', '');
    self.set_user_role(user_id, 'admin');
    self.set_requires_password_reset(user_id, True);

    logger.warning(
        f"Admin user '{admin_username}' created with default password. Please change immediately!"
    );
    return {
        'message': 'Admin user created successfully',
        'username': admin_username,
        'user_id': user_id
    };
}

impl JacScaleUserManager.create_user_as_admin(
    username: str,
    password: str,
    role: str = 'user',
    requires_password_reset: bool = True
) -> dict[str, Any] {
    valid_roles = [r.value for r in UserRole];
    if role not in valid_roles {
        return {'error': f"Invalid role. Must be one of: {', '.join(valid_roles)}"};
    }
    result = self.create_internal_user(username, password);
    if 'error' in result {
        return result;
    }
    user_id = result.get('user_id', '');

    self._identity_storage.update_user_fields(
        user_id, {'role': role, 'requires_password_reset': requires_password_reset}
    );
    result['username'] = username;
    result['role'] = role;
    result['requires_password_reset'] = str(requires_password_reset);
    return result;
}
