impl JacScaleUserManager.postinit -> None {
    sso_config = get_scale_config().get_sso_config();
    for platform in Platforms {
        key = platform.value.lower();
        platform_config = sso_config.get(key, {});

        if platform.value == Platforms.FIREBASE.value {
            project_id = platform_config.get('project_id', '');
            if not project_id {
                continue;
            }
            self.SUPPORTED_PLATFORMS[platform.value] = {"project_id": project_id};
        } else {
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
    }

    db_config = get_scale_config().get_database_config();
    mongodb_uri = db_config.get('mongodb_uri');

    if mongodb_uri is not None {
        import from jaclang.scale.persistence.db { get_mongo_client }
        client = get_mongo_client();
        db = client['jac_db'];
        self._identity_storage = MongoIdentityStorage(users_col=db['users']);
        self._identity_storage.ensure_indexes();
    } else {
        import os;
        base_for_data = os.environ.get('JAC_DATA_PATH', self.base_path);
        data_dir = os.path.join(base_for_data, '.jac', 'data');
        os.makedirs(data_dir, exist_ok=True);
        db_path = os.path.join(data_dir, 'users.db');
        self._identity_storage = SqliteIdentityStorage(db_path=db_path);
    }
}

impl JacScaleUserManager.create_user(username: str, password: str) -> dict[str, any] {
    return self.create_user_with_identities(
        identities=[{'type': 'username', 'value': username}],
        credential={'type': 'password', 'password': password}
    );
}

impl JacScaleUserManager.create_user_with_identities(
    identities: list[dict[str, any]],
    credential: dict[str, any],
    profile: dict[str, any] | None = None
) -> dict[str, any] {
    return self._identity_storage.create_user(identities, credential, profile);
}

impl JacScaleUserManager.create_internal_user(
    username: str, password: str, role: str = 'user'
) -> dict[str, any] {
    result = self.create_user(username, password);
    if result.get('user_id') and role != 'user' {
        self.set_user_role(result['user_id'], role);
    }
    return result;
}

impl JacScaleUserManager.authenticate(
    identifier: str, password: str
) -> dict[str, any] | None {
    result = self._identity_storage.authenticate(identifier, password);
    if result is not None {
        result['token'] = self.create_jwt_token(result.get('user_id', ''));
    }
    return result;
}

impl JacScaleUserManager.find_user_by_identity(value: str) -> dict[str, any] | None {
    return self._identity_storage.find_user_by_identity(value);
}

impl JacScaleUserManager.user_exists(user_id: str) -> bool {
    if self._identity_storage.user_exists_by_id(user_id) {
        return True;
    }
    return self._identity_storage.find_user_by_identity(user_id) is not None;
}

impl JacScaleUserManager.get_user(user_id: str) -> dict[str, any] | None {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return user;
}

impl JacScaleUserManager.get_root_id(user_id: str) -> str | None {
    if user_id == '__system__' {
        return Con.SUPER_ROOT_UUID;
    }
    cache = _root_id_request_cache.get();
    if cache is not None and user_id in cache {
        return cache[user_id];
    }
    result = self._identity_storage.get_root_id(user_id);
    if not result {
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

impl JacScaleUserManager.update_password(
    user_id: str, current_password: str, new_password: str
) -> dict[str, str] {
    return self._identity_storage.update_password(
        user_id, current_password, new_password
    );
}

impl JacScaleUserManager.reset_password_by_user_id(
    user_id: str, new_password: str
) -> dict[str, str] {
    return self._identity_storage.reset_password(user_id, new_password);
}

impl JacScaleUserManager.add_identity(user_id: str, identity: dict[str, any]) -> bool {
    return self._identity_storage._add_identity(user_id, identity);
}

impl JacScaleUserManager.is_identity_taken(value: str) -> bool {
    return self._identity_storage.identity_taken(value);
}

impl JacScaleUserManager.set_identity_verified(
    user_id: str, value_normalized: str
) -> bool {
    return self._identity_storage._set_identity_verified(user_id, value_normalized);
}

impl JacScaleUserManager.update_profile(
    user_id: str, profile_updates: dict[str, any]
) -> dict[str, any] {
    user = self.get_user(user_id);
    if not user {
        return {'error': 'User not found'};
    }
    raw_profile = user.get('profile');
    current_profile: dict[str, any] = (
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

impl JacScaleUserManager.get_username(user_id: str) -> str | None {
    return self._identity_storage.get_username(user_id);
}

impl JacScaleUserManager.create_jwt_token(
    user_id: str, include_role: bool = True
) -> str {
    now = datetime.now(UTC);
    payload: dict[(str, any)] = {
        'user_id': user_id,
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

impl JacScaleUserManager.validate_jwt_token(token: str) -> str | None {
    try {
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
        if decoded.get('type') == 'api_key' {
            return None;
        }
        return decoded.get('user_id') or None;
    } except Exception as e {
        logger.debug(f"Failed to validate JWT token: {str(e)}");
        return None;
    }
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

impl JacScaleUserManager.get_sso(platform: str) -> SSOProvider | None {
    if platform not in self.SUPPORTED_PLATFORMS {
        return None;
    }
    credentials = self.SUPPORTED_PLATFORMS[platform];
    if platform == Platforms.FIREBASE.value {
        import from jaclang.scale.sso.firebase { FirebaseSSOProvider }
        return FirebaseSSOProvider(project_id=credentials['project_id']);
    } elif platform == Platforms.GOOGLE.value {
        redirect_uri = f"{SSO_HOST}/sso/{platform}/callback";
        import from jaclang.scale.sso.google { GoogleSSOProvider }
        return GoogleSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    } elif platform == Platforms.APPLE.value {
        redirect_uri = f"{SSO_HOST}/sso/{platform}/callback";
        import from jaclang.scale.sso.apple { AppleSSOProvider }
        return AppleSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    } elif platform == Platforms.GITHUB.value {
        redirect_uri = f"{SSO_HOST}/sso/{platform}/callback";
        import from jaclang.scale.sso.github { GithubSSOProvider }
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
    platform: str, operation: str, client_callback: str | None = None
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

    if platform == Platforms.FIREBASE.value {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=(
                "Firebase Auth does not use redirect-based SSO flows. "
                "Send the Firebase ID token directly to "
                "POST /sso/firebase/token with a JSON body "
                '{"id_token": "<token>"}.'
            ),
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

    state = client_callback if is_safe_loopback_redirect(client_callback) else None;
    return await sso.initiate_auth(state=state);
}

impl JacScaleUserManager.sso_callback(
    request: Request, platform: str
) -> TransportResponse {
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
    } except Exception as e {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=f"Authentication failed: {str(e)}",
            meta=Meta(extra={'http_status': 401})
        );
    }

    return self._complete_sso_login(platform, user_info);
}

impl JacScaleUserManager.firebase_token_auth_with_id_token(
    id_token: str
) -> TransportResponse {
    platform = Platforms.FIREBASE.value;
    if platform not in self.SUPPORTED_PLATFORMS {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=(
                "Firebase Auth SSO is not configured. Set "
                "[scale.sso.firebase] project_id in jac.toml or "
                f"{firebase_project_id_env_hint()}"
            ),
            meta=Meta(extra={'http_status': 501})
        );
    }
    sso = self.get_sso(platform);
    try {
        user_info = await sso.handle_id_token(id_token);
    } except Exception as e {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=f"Firebase authentication failed: {str(e)}",
            meta=Meta(extra={'http_status': 401})
        );
    }

    return self._complete_sso_login(platform, user_info);
}

impl JacScaleUserManager._complete_sso_login(
    platform: str, user_info: SSOUserInfo
) -> TransportResponse {
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

        self.link_sso_account(user_id, platform, external_id);

        if sso_fields {
            raw_profile = existing.get('profile') if existing else None;
            current_profile: dict[str, any] = (
                raw_profile if isinstance(raw_profile, dict) else {}
            );

            raw_sso = current_profile.get('sso');
            current_sso: dict[str, any] = raw_sso if isinstance(raw_sso, dict) else {};
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

    sso_profile = {'sso': {platform: sso_fields}} if sso_fields else None;
    result = self.create_user_with_identities(
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

    self.link_sso_account(user_id, platform, external_id);
    result['token'] = self.create_jwt_token(user_id);
    result['platform'] = platform;
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 201})
    );
}

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

impl JacScaleUserManager.get_user_role(user_id: str) -> str | None {
    role = self._identity_storage.get_user_role(user_id);
    if role is None {
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

impl JacScaleUserManager.requires_password_reset(user_id: str) -> bool {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return bool(user.get('requires_password_reset', False)) if user else False;
}

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

impl JacScaleUserManager.is_password_required(user_id: str) -> bool {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return True if not user else bool(user.get('is_password_required', True));
}

impl JacScaleUserManager.list_all_users(
    limit: int = 100, offset: int = 0
) -> list[dict[str, any]] {
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
) -> dict[str, any] {
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
