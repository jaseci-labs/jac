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
        users_col = db['users'];
        sso_col = db['sso_accounts'];
        users_col.create_index('username', unique=True);
        users_col.create_index('token', unique=True, sparse=True);
        sso_col.create_index([('platform', 1), ('external_id', 1)], unique=True);
        sso_col.create_index('user_id');
        self._storage = MongoUserStorage(users_col=users_col, sso_col=sso_col);
    } else {
        self._storage = None;
        super.postinit();
        self._init_sqlite_schema();
    }
}

"""Initialize SQLite schema for extended fields."""
impl JacScaleUserManager._init_sqlite_schema -> None {
    self._ensure_connection();
    self._conn.execute(
        """
        CREATE TABLE IF NOT EXISTS sso_accounts (
            user_id TEXT NOT NULL,
            platform TEXT NOT NULL,
            external_id TEXT NOT NULL,
            email TEXT,
            linked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (platform, external_id),
            FOREIGN KEY (user_id) REFERENCES users(username) ON DELETE CASCADE
        )
    """
    );
    self._conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_sso_accounts_user_id ON sso_accounts(user_id)"
    );
    cursor = self._conn.execute("PRAGMA table_info(users)");
    cols = {row[1] for row in cursor.fetchall()};
    if 'role' not in cols {
        self._conn.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user'");
    }
    if 'requires_password_reset' not in cols {
        self._conn.execute(
            "ALTER TABLE users ADD COLUMN requires_password_reset INTEGER DEFAULT 0"
        );
    }
    if 'is_password_required' not in cols {
        self._conn.execute(
            "ALTER TABLE users ADD COLUMN is_password_required INTEGER DEFAULT 1"
        );
    }
    if 'user_id' not in cols {
        self._conn.execute("ALTER TABLE users ADD COLUMN user_id TEXT");
    }
    self._conn.commit();
}

impl JacScaleUserManager._ensure_connection -> None {
    if self._storage is None {
        super._ensure_connection();
    }
}

# ============================================================================
# User CRUD - delegate to storage or parent
# ============================================================================
impl JacScaleUserManager.create_user(username: str, password: str) -> dict[str, str] {
    return self._storage.create_user(username, password)
        if self._storage
        else super.create_user(username, password);
}

impl JacScaleUserManager.authenticate(
    username: str, password: str
) -> (dict[(str, str)] | None) {
    return self._storage.authenticate(username, password)
        if self._storage
        else super.authenticate(username, password);
}

impl JacScaleUserManager.get_root_id(username: str) -> (str | None) {
    return self._storage.get_root_id(username)
        if self._storage
        else super.get_root_id(username);
}

impl JacScaleUserManager.get_user(username: str) -> (dict[(str, str)] | None) {
    return self._storage.get_user(username)
        if self._storage
        else super.get_user(username);
}

impl JacScaleUserManager.user_exists(username: str) -> bool {
    return self._storage.user_exists(username)
        if self._storage
        else super.user_exists(username);
}

impl JacScaleUserManager.update_username(
    current_username: str, new_username: str
) -> dict[str, str] {
    return self._storage.update_username(current_username, new_username)
        if self._storage
        else super.update_username(current_username, new_username);
}

impl JacScaleUserManager.update_password(
    username: str, current_password: str, new_password: str
) -> dict[str, str] {
    return self._storage.update_password(username, current_password, new_password)
        if self._storage
        else super.update_password(username, current_password, new_password);
}

impl JacScaleUserManager.validate_token(token: str) -> (str | None) {
    return self.validate_jwt_token(token);
}

impl JacScaleUserManager.close -> None { }

# ============================================================================
# JWT Methods
# ============================================================================
impl JacScaleUserManager.create_jwt_token(
    username: str, include_role: bool = True
) -> str {
    now = datetime.now(UTC);
    payload: dict[(str, Any)] = {
        'username': username,
        'exp': (now + timedelta(days=JWT_EXP_DELTA_DAYS)),
        'iat': now.timestamp()
    };
    if include_role {
        role = self.get_user_role(username);
        if role {
            payload['role'] = role;
        }
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM);
}

impl JacScaleUserManager.get_jwt_claims(token: str) -> (dict | None) {
    try {
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
    } except Exception as e {
        logger.debug(f"Failed to decode JWT token: {str(e)}");
        return None;
    }
}

impl JacScaleUserManager.validate_jwt_token(token: str) -> (str | None) {
    try {
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
        username = decoded['username'];
        return username if self.user_exists(username) else None;
    } except Exception as e {
        logger.debug(f"Failed to validate JWT token: {str(e)}");
        return None;
    }
}

impl JacScaleUserManager.refresh_jwt_token(token: str) -> (str | None) {
    try {
        decoded = jwt.decode(
            token, JWT_SECRET, algorithms=[JWT_ALGORITHM], options={"verify_exp": True}
        );
        username = decoded.get('username');
        return self.create_jwt_token(username) if username else None;
    } except Exception as e {
        logger.debug(f"Failed to refresh JWT token: {str(e)}");
        return None;
    }
}

# ============================================================================
# SSO Methods
# ============================================================================
impl JacScaleUserManager.get_sso(platform: str) -> (SSOProvider | None) {
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
) -> (Response | TransportResponse) {
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
            message=f"SSO for platform '{platform}' is not configured. Please set SSO_{platform.upper()}_CLIENT_ID and SSO_{platform.upper()}_CLIENT_SECRET environment variables.",
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
        user = self.get_user(email);
        if user {
            # User exists — login
            token = self.create_jwt_token(email);
            return TransportResponse.success(
                data={
                    'message': 'Login successful',
                    'email': email,
                    'token': token,
                    'platform': platform,
                    'user': dict[(str, JsonValue)](user)
                },
                meta=Meta(extra={'http_status': 200})
            );
        } else {
            # User does not exist — register then login
            result = self.create_user(email, generate_random_password());
            if 'error' in result {
                return TransportResponse.fail(
                    code='USER_CREATION_FAILED',
                    message=result.get('error', 'User creation failed'),
                    meta=Meta(extra={'http_status': 400})
                );
            }
            result['token'] = self.create_jwt_token(email);
            result['platform'] = platform;
            return TransportResponse.success(
                data=result, meta=Meta(extra={'http_status': 201})
            );
        }
    } except Exception as e {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=f"Authentication failed: {str(e)}",
            meta=Meta(extra={'http_status': 500})
        );
    }
}

# ============================================================================
# SSO Account Linking - delegate to storage or SQLite
# ============================================================================
impl JacScaleUserManager.link_sso_account(
    user_id: str, platform: str, external_id: str, email: str
) -> dict[str, str] {
    if self._storage {
        return self._storage.link_sso_account(user_id, platform, external_id, email);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT user_id FROM sso_accounts WHERE platform = ? AND external_id = ?",
        (platform, external_id)
    );
    existing = cursor.fetchone();
    if existing {
        if existing[0] == user_id {
            return {'message': 'SSO account already linked to this user'};
        }
        return {'error': 'This SSO account is already linked to another user'};
    }
    self._conn.execute(
        "INSERT INTO sso_accounts (user_id, platform, external_id, email) VALUES (?, ?, ?, ?)",
        (user_id, platform, external_id, email)
    );
    self._conn.commit();
    return {
        'message': 'SSO account linked successfully',
        'user_id': user_id,
        'platform': platform
    };
}

impl JacScaleUserManager.unlink_sso_account(
    user_id: str, platform: str
) -> dict[str, str] {
    if self._storage {
        return self._storage.unlink_sso_account(user_id, platform);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "DELETE FROM sso_accounts WHERE user_id = ? AND platform = ?",
        (user_id, platform)
    );
    self._conn.commit();
    if cursor.rowcount == 0 {
        return {'error': 'SSO account not found'};
    }
    return {
        'message': 'SSO account unlinked successfully',
        'user_id': user_id,
        'platform': platform
    };
}

impl JacScaleUserManager.get_sso_accounts(user_id: str) -> list[dict[str, str]] {
    if self._storage {
        return self._storage.get_sso_accounts(user_id);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT platform, external_id, email, linked_at FROM sso_accounts WHERE user_id = ? ORDER BY linked_at DESC",
        (user_id, )
    );
    return [
        {'platform': r[0], 'external_id': r[1], 'email': r[2], 'linked_at': r[3]}
        for r in cursor.fetchall()
    ];
}

impl JacScaleUserManager.get_user_by_sso(
    platform: str, external_id: str
) -> (dict[str, str] | None) {
    if self._storage {
        return self._storage.get_user_by_sso(platform, external_id);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT sa.user_id, u.token, u.root_id FROM sso_accounts sa JOIN users u ON sa.user_id = u.username WHERE sa.platform = ? AND sa.external_id = ?",
        (platform, external_id)
    );
    row = cursor.fetchone();
    return {'email': row[0], 'token': row[1], 'root_id': row[2]} if row else None;
}

# ============================================================================
# User Role and Admin Management
# ============================================================================
impl JacScaleUserManager.get_user_role(username: str) -> (str | None) {
    if self._storage {
        return self._storage.get_user_role(username);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT role FROM users WHERE username = ?", (username, )
    );
    row = cursor.fetchone();
    return (row[0] or 'user') if row else None;
}

impl JacScaleUserManager.set_user_role(username: str, role: str) -> dict[str, str] {
    valid_roles = [r.value for r in UserRole];
    if role not in valid_roles {
        return {'error': f"Invalid role. Must be one of: {', '.join(valid_roles)}"};
    }
    if self._storage {
        return self._storage.set_user_role(username, role);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "UPDATE users SET role = ? WHERE username = ?", (role, username)
    );
    self._conn.commit();
    if cursor.rowcount == 0 {
        return {'error': 'User not found'};
    }
    return {
        'message': f"Role updated to '{role}'",
        'username': username,
        'role': role
    };
}

impl JacScaleUserManager.is_admin(username: str) -> bool {
    return self.get_user_role(username) == 'admin';
}

impl JacScaleUserManager.requires_password_reset(username: str) -> bool {
    if self._storage {
        return self._storage.requires_password_reset(username);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT requires_password_reset FROM users WHERE username = ?", (username, )
    );
    row = cursor.fetchone();
    return bool(row[0]) if row else False;
}

impl JacScaleUserManager.set_requires_password_reset(
    username: str, requires_reset: bool
) -> dict[str, str] {
    if self._storage {
        return self._storage.set_requires_password_reset(username, requires_reset);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "UPDATE users SET requires_password_reset = ? WHERE username = ?",
        (1 if requires_reset else 0, username)
    );
    self._conn.commit();
    return {'error': 'User not found'}
        if cursor.rowcount == 0
        else {'message': 'Password reset requirement updated', 'username': username};
}

impl JacScaleUserManager.is_password_required(username: str) -> bool {
    if self._storage {
        return self._storage.is_password_required(username);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT is_password_required FROM users WHERE username = ?", (username, )
    );
    row = cursor.fetchone();
    if not row {
        return True;
    }
    return bool(row[0]) if row[0] is not None else True;
}

impl JacScaleUserManager.set_password_required(
    username: str, required: bool
) -> dict[str, str] {
    if self._storage {
        return self._storage.set_password_required(username, required);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "UPDATE users SET is_password_required = ? WHERE username = ?",
        (1 if required else 0, username)
    );
    self._conn.commit();
    return {'error': 'User not found'}
        if cursor.rowcount == 0
        else {'message': 'Password requirement updated', 'username': username};
}

impl JacScaleUserManager.list_all_users(
    limit: int = 100, offset: int = 0
) -> list[dict[str, Any]] {
    if self._storage {
        return self._storage.list_all_users(limit, offset);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT username, root_id, role, requires_password_reset, is_password_required, user_id FROM users WHERE username != ? ORDER BY username LIMIT ? OFFSET ?",
        (Con.GUEST.value, limit, offset)
    );
    return [
        {
            'username': r[0] or '',
            'root_id': r[1] or '',
            'role': r[2] or 'user',
            'requires_password_reset': bool(r[3]),
            'is_password_required': bool(r[4]) if r[4] is not None else True,
            'user_id': r[5]
        } for r in cursor.fetchall()
    ];
}

impl JacScaleUserManager.delete_user(username: str) -> dict[str, str] {
    if self._storage {
        return self._storage.delete_user(username, self.ADMIN_USER_ID);
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT user_id FROM users WHERE username = ?", (username, )
    );
    user = cursor.fetchone();
    if user and user[0] == self.ADMIN_USER_ID {
        return {'error': 'Cannot delete the primary admin user'};
    }
    cursor = self._conn.execute("DELETE FROM users WHERE username = ?", (username, ));
    self._conn.commit();
    if cursor.rowcount == 0 {
        return {'error': 'User not found'};
    }
    self._conn.execute("DELETE FROM sso_accounts WHERE user_id = ?", (username, ));
    self._conn.commit();
    return {'message': 'User deleted successfully', 'username': username};
}

impl JacScaleUserManager.bootstrap_admin_user -> dict[str, str] {
    admin_config = get_scale_config().get_admin_config();
    if not admin_config.get('enabled', True) {
        return {'message': 'Admin portal is disabled'};
    }
    admin_username = admin_config.get('username', 'admin');
    default_password = admin_config.get('default_password', 'changeme');
    require_reset = admin_config.get('require_password_reset', True);

    existing_admin = self.get_user(admin_username);
    if existing_admin {
        if self.get_user_role(admin_username) != 'admin' {
            if self._storage {
                self._storage.update_user_fields(
                    admin_username, {'role': 'admin', 'user_id': self.ADMIN_USER_ID}
                );
            } else {
                self.set_user_role(admin_username, 'admin');
                self._ensure_connection();
                try {
                    self._conn.execute(
                        "UPDATE users SET user_id = ? WHERE username = ?",
                        (self.ADMIN_USER_ID, admin_username)
                    );
                    self._conn.commit();
                } except Exception as e {
                    logger.error(
                        f"Failed to set user_id for admin user '{admin_username}': {str(
                            e
                        )}"
                    );
                }
            }
            logger.info(f"Existing user '{admin_username}' promoted to admin role");
        }
        return {'message': 'Admin user already exists', 'username': admin_username};
    }

    result = self.create_user(admin_username, default_password);
    if 'error' in result {
        return result;
    }
    if self._storage {
        self._storage.update_user_fields(
            admin_username,
            {
                'role': 'admin',
                'user_id': self.ADMIN_USER_ID,
                'requires_password_reset': require_reset
            }
        );
    } else {
        self.set_user_role(admin_username, 'admin');
        self.set_requires_password_reset(admin_username, require_reset);
        self._ensure_connection();
        try {
            self._conn.execute(
                "UPDATE users SET user_id = ? WHERE username = ?",
                (self.ADMIN_USER_ID, admin_username)
            );
            self._conn.commit();
        } except Exception as e {
            logger.error(
                f"Failed to set user_id for newly created admin user '{admin_username}': {str(
                    e
                )}"
            );
        }
    }
    logger.warning(
        f"Admin user '{admin_username}' created with default password. Please change immediately!"
    );
    return {
        'message': 'Admin user created successfully',
        'username': admin_username,
        'user_id': self.ADMIN_USER_ID,
        'requires_password_reset': str(require_reset)
    };
}

impl JacScaleUserManager.create_user_as_admin(
    username: str,
    password: str,
    role: str = 'user',
    requires_password_reset: bool = True
) -> dict[str, Any] {
    import uuid;
    valid_roles = [r.value for r in UserRole];
    if role not in valid_roles {
        return {'error': f"Invalid role. Must be one of: {', '.join(valid_roles)}"};
    }
    result = self.create_user(username, password);
    if 'error' in result {
        return result;
    }
    user_id = str(uuid.uuid4());
    if self._storage {
        self._storage.update_user_fields(
            username,
            {
                'role': role,
                'user_id': user_id,
                'requires_password_reset': requires_password_reset
            }
        );
    } else {
        self._ensure_connection();
        self._conn.execute(
            "UPDATE users SET role = ?, user_id = ?, requires_password_reset = ? WHERE username = ?",
            (role, user_id, 1 if requires_password_reset else 0, username)
        );
        self._conn.commit();
    }
    result['role'] = role;
    result['user_id'] = user_id;
    result['requires_password_reset'] = str(requires_password_reset);
    return result;
}
