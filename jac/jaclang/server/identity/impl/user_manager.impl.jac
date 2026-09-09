impl UserManager.postinit -> None {
    import from jaclang.server.shared_store {
        NO_DATABASE_RESOLVED,
        shared_store,
        shared_store_failure
    }
    store = shared_store();
    if store is None {
        raise RuntimeError(
            'identity storage requires a reachable Postgres database: '
            f"{shared_store_failure() or NO_DATABASE_RESOLVED}. Refusing to "
            'fall back to a second credential store; fix the database and '
            'restart.'
        );
    }
    self._identity_storage = PgIdentityStorage(store=store);
}

impl UserManager.create_user(username: str, password: str) -> dict[str, any] {
    return self.create_user_with_identities(
        identities=[{'type': 'username', 'value': username}],
        credential={'type': 'password', 'password': password}
    );
}

impl UserManager.create_user_with_identities(
    identities: list[dict[str, any]],
    credential: dict[str, any],
    profile: dict[str, any] | None = None
) -> dict[str, any] {
    return self._identity_storage.create_user(identities, credential, profile);
}

impl UserManager.create_internal_user(
    username: str, password: str, role: str = 'user'
) -> dict[str, any] {
    result = self.create_user(username, password);
    if result.get('user_id') and role != 'user' {
        self.set_user_role(result['user_id'], role);
    }
    return result;
}

impl UserManager.ensure_internal_user(
    username: str, password: str, role: str = 'user'
) -> dict[str, any] {
    existing = self.find_user_by_identity(username);
    if existing {
        user_id = str(existing.get('user_id') or '');
        if role != 'user' and self.get_user_role(user_id) != role {
            self.set_user_role(user_id, role);
        }
        return existing;
    }
    created = self.create_internal_user(username, password, role);
    if 'error' in created {
        again = self.find_user_by_identity(username);
        if again {
            return again;
        }
    }
    return created;
}

impl UserManager.aget_root_id(user_id: str) -> str | None {
    import asyncio;
    return await asyncio.to_thread(self.get_root_id, user_id);
}

impl UserManager.update_user_fields(user_id: str, fields: dict[str, any]) -> bool {
    return self._identity_storage.update_user_fields(user_id, fields);
}

impl UserManager.authenticate(identifier: str, password: str) -> dict[str, any] | None {
    result = self._identity_storage.authenticate(identifier, password);
    if result is not None {
        result['token'] = self.create_jwt_token(result.get('user_id', ''));
    }
    return result;
}

impl UserManager.find_user_by_identity(value: str) -> dict[str, any] | None {
    return self._identity_storage.find_user_by_identity(value);
}

impl UserManager.user_exists(user_id: str) -> bool {
    if self._identity_storage.user_exists_by_id(user_id) {
        return True;
    }
    return self._identity_storage.find_user_by_identity(user_id) is not None;
}

impl UserManager.get_user(user_id: str) -> dict[str, any] | None {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return user;
}

impl UserManager.get_root_id(user_id: str) -> str | None {
    if user_id == SYSTEM_USER {
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

impl UserManager.reset_root(identifier: str) -> str | None {
    user = self.get_user(identifier);
    if not user {
        return None;
    }
    new_root = self._identity_storage.reset_root(str(user.get('user_id') or ''));
    if new_root {
        cache = _root_id_request_cache.get();
        if cache is not None {
            _root_id_request_cache.set(None);
        }
    }
    return new_root;
}

impl UserManager.ensure_user_root(user_id: str) -> str | None {
    if not user_id or user_id == SYSTEM_USER {
        return None;
    }
    return self._identity_storage.ensure_user_by_id(user_id);
}

impl UserManager.update_password(
    user_id: str, current_password: str, new_password: str
) -> dict[str, str] {
    return self._identity_storage.update_password(
        user_id, current_password, new_password
    );
}

impl UserManager.reset_password_by_user_id(
    user_id: str, new_password: str
) -> dict[str, str] {
    return self._identity_storage.reset_password(user_id, new_password);
}

impl UserManager.add_identity(user_id: str, identity: dict[str, any]) -> bool {
    return self._identity_storage._add_identity(user_id, identity);
}

impl UserManager.rename_username(user_id: str, new_username: str) -> dict[str, any] {
    return self._identity_storage.rename_username(user_id, new_username);
}

impl UserManager.is_identity_taken(value: str) -> bool {
    return self._identity_storage.identity_taken(value);
}

impl UserManager.set_identity_verified(user_id: str, value_normalized: str) -> bool {
    return self._identity_storage._set_identity_verified(user_id, value_normalized);
}

impl UserManager.update_profile(
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

impl UserManager.validate_token(token: str) -> str | None {
    return self.validate_jwt_token(token);
}

impl UserManager.close -> None {}

impl UserManager.get_username(user_id: str) -> str | None {
    return self._identity_storage.get_username(user_id);
}

impl UserManager.create_jwt_token(user_id: str, include_role: bool = True) -> str {
    now = datetime.now(UTC);
    payload: dict[(str, any)] = {
        'sub': user_id,
        'user_id': user_id,
        'exp': (now + timedelta(days=token_ttl_days())),
        'iat': now.timestamp()
    };
    username = self.get_username(user_id);
    if username {
        payload['preferred_username'] = username;
    }
    if include_role {
        role = self.get_user_role(user_id);
        if role {
            payload['role'] = role;
        }
    }
    return jwt_encode(payload, signing_secret(), algorithm=signing_algorithm());
}

impl UserManager.get_jwt_claims(token: str) -> dict | None {
    try {
        return jwt_decode(token, signing_secret(), algorithms=[signing_algorithm()]);
    } except Exception as e {
        logger.debug(f"Failed to decode JWT token: {str(e)}");
        return None;
    }
}

impl UserManager.validate_jwt_token(token: str) -> str | None {
    user_id = self.validate_jwt_token_detail(token, check_existence=False)['user_id'];
    return str(user_id) if user_id is not None else None;
}

impl UserManager.validate_jwt_token_detail(
    token: str | None, check_existence: bool = True
) -> dict[str, any] {
    if not token {
        return {
            'status': 'missing',
            'user_id': None,
            'exp': None,
            'reason': 'No token provided'
        };
    }
    try {
        decoded = jwt_decode(
            token, signing_secret(), algorithms=[signing_algorithm()], verify_exp=True
        );
    } except JWTExpiredError {
        return {
            'status': 'expired',
            'user_id': None,
            'exp': None,
            'reason': 'Token expired'
        };
    } except Exception as e {
        logger.debug(f"Failed to validate JWT token: {str(e)}");
        return {
            'status': 'invalid',
            'user_id': None,
            'exp': None,
            'reason': 'Token invalid'
        };
    }
    if decoded.get('type') == 'api_key' {
        return {
            'status': 'invalid',
            'user_id': None,
            'exp': decoded.get('exp'),
            'reason': 'API key tokens are not valid user sessions'
        };
    }
    user_id = decoded.get('sub') or decoded.get('user_id');
    if not user_id {
        return {
            'status': 'invalid',
            'user_id': None,
            'exp': decoded.get('exp'),
            'reason': 'Token has no subject'
        };
    }
    if check_existence and not self.user_exists(user_id) {
        provisioned = self.ensure_user_root(user_id)
            if self.provision_unknown_users
            else None;
        if not provisioned {
            return {
                'status': 'unknown_user',
                'user_id': None,
                'exp': decoded.get('exp'),
                'reason': 'User associated with token no longer exists'
            };
        }
        logger.info(
            f"Provisioned a local root for gateway-issued user {user_id} "
            f"on this service"
        );
    }
    return {
        'status': 'ok',
        'user_id': user_id,
        'exp': decoded.get('exp'),
        'reason': None
    };
}

impl UserManager.refresh_jwt_token(token: str) -> str | None {
    try {
        decoded = jwt_decode(
            token, signing_secret(), algorithms=[signing_algorithm()], verify_exp=True
        );
        if decoded.get('type') == 'api_key' {
            return None;
        }
        user_id = decoded.get('sub') or decoded.get('user_id');
        return self.create_jwt_token(user_id) if user_id else None;
    } except Exception as e {
        logger.debug(f"Failed to refresh JWT token: {str(e)}");
        return None;
    }
}

impl UserManager.link_sso_account(
    user_id: str, platform: str, external_id: str
) -> dict[str, str] {
    return self._identity_storage.link_sso_account(user_id, platform, external_id);
}

impl UserManager.unlink_sso_account(user_id: str, platform: str) -> dict[str, str] {
    return self._identity_storage.unlink_sso_account(user_id, platform);
}

impl UserManager.get_sso_accounts(user_id: str) -> list[dict[str, str]] {
    return self._identity_storage.get_sso_accounts(user_id);
}

impl UserManager.get_user_by_sso(
    platform: str, external_id: str
) -> dict[str, str] | None {
    return self._identity_storage.get_user_by_sso(platform, external_id);
}

impl UserManager.get_user_role(user_id: str) -> str | None {
    role = self._identity_storage.get_user_role(user_id);
    if role is None {
        user = self._identity_storage.find_user_by_identity(user_id);
        if user {
            return user.get('role', 'user');
        }
    }
    return role;
}

impl UserManager.set_user_role(user_id: str, role: str) -> dict[str, str] {
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

impl UserManager.is_admin(user_id: str) -> bool {
    return self.get_user_role(user_id) == 'admin';
}

impl UserManager.requires_password_reset(user_id: str) -> bool {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return bool(user.get('requires_password_reset', False)) if user else False;
}

impl UserManager.set_requires_password_reset(
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

impl UserManager.expire_legacy_credentials(
    username: (str | None) = None
) -> dict[str, any] {
    target_id: (str | None) = None;
    if username is not None {
        user = self.get_user(username);
        if not user {
            return {'error': 'User not found'};
        }
        target_id = str(user.get('user_id', username));
    }
    expired = self._identity_storage.expire_legacy_credentials(target_id);
    return {'expired_user_ids': expired, 'count': len(expired)};
}

impl UserManager.is_password_required(user_id: str) -> bool {
    user = self._identity_storage.get_user_by_id(user_id);
    if not user {
        user = self._identity_storage.find_user_by_identity(user_id);
    }
    return True if not user else bool(user.get('is_password_required', True));
}

impl UserManager.list_all_users(
    limit: int = 100, offset: int = 0
) -> list[dict[str, any]] {
    return self._identity_storage.list_all_users(limit, offset);
}

impl UserManager.delete_user(user_id: str) -> dict[str, str] {
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

impl UserManager.bootstrap_admin_user(
    admin_username: str = 'admin', default_password: str = 'changeme'
) -> dict[str, str] {
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

impl UserManager.create_user_as_admin(
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
