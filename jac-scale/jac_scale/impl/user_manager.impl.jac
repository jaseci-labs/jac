impl JacScaleUserManager.postinit -> None {
    super.postinit();
    # Create SSO accounts table for tracking linked external identities
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
    # Create index for faster lookups by user_id
    self._conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_sso_accounts_user_id ON sso_accounts(user_id)"
    );
    # Add role, requires_password_reset, and is_password_required columns to users table
    # SQLite doesn't support IF NOT EXISTS for ALTER TABLE, so check column existence first
    cursor = self._conn.execute("PRAGMA table_info(users)");
    existing_columns = {row[1] for row in cursor.fetchall()};
    if 'role' not in existing_columns {
        self._conn.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user'");
    }
    if 'requires_password_reset' not in existing_columns {
        self._conn.execute(
            "ALTER TABLE users ADD COLUMN requires_password_reset INTEGER DEFAULT 0"
        );
    }
    if 'is_password_required' not in existing_columns {
        self._conn.execute(
            "ALTER TABLE users ADD COLUMN is_password_required INTEGER DEFAULT 1"
        );
    }
    if 'user_id' not in existing_columns {
        self._conn.execute("ALTER TABLE users ADD COLUMN user_id TEXT");
    }
    self._conn.commit();
    # Load SSO config
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
}

impl JacScaleUserManager.create_jwt_token(
    username: str, include_role: bool = True
) -> str {
    now = datetime.now(UTC);
    payload: dict[(str, Any)] = {
        'username': username,
        'exp': (now + timedelta(days=JWT_EXP_DELTA_DAYS)),
        'iat': now.timestamp()
    };
    # Include role in JWT claims if requested
    if include_role {
        role = self.get_user_role(username);
        if role {
            payload['role'] = role;
        }
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM);
}

"""Get JWT claims from token without full validation."""
impl JacScaleUserManager.get_jwt_claims(token: str) -> (dict | None) {
    try {
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
        return decoded;
    } except Exception {
        return None;
    }
}

impl JacScaleUserManager.validate_jwt_token(token: str) -> (str | None) {
    try {
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
        username = decoded['username'];
        if not self.user_exists(username) {
            return None;
        }
        return username;
    } except Exception {
        return None;
    }
}

impl JacScaleUserManager.refresh_jwt_token(token: str) -> (str | None) {
    try {
        decoded = jwt.decode(
            token, JWT_SECRET, algorithms=[JWT_ALGORITHM], options={"verify_exp": True}
        );
        username = decoded.get('username');

        if not username {
            return None;
        }

        return self.create_jwt_token(username);
    } except Exception {
        return None;
    }
}

impl JacScaleUserManager.validate_token(token: str) -> (str | None) {
    return self.validate_jwt_token(token);
}

impl JacScaleUserManager.get_sso(platform: str, operation: str) -> (SSOProvider | None) {
    if (platform not in self.SUPPORTED_PLATFORMS) {
        return None;
    }
    credentials = self.SUPPORTED_PLATFORMS[platform];
    redirect_uri = f"{SSO_HOST}/{platform}/{operation}/callback";
    if (platform == Platforms.GOOGLE.value) {
        import from jac_scale.google_sso_provider { GoogleSSOProvider }
        return GoogleSSOProvider(
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
    import from jaclang.runtimelib.server { JsonValue }
    if (platform not in [p.value for p in Platforms]) {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    if (platform not in self.SUPPORTED_PLATFORMS) {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured. Please set SSO_{platform.upper()}_CLIENT_ID and SSO_{platform.upper()}_CLIENT_SECRET environment variables.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    if (operation not in [o.value for o in Operations]) {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=f"Invalid operation '{operation}'. Must be 'login' or 'register'",
            meta=Meta(extra={'http_status': 400})
        );
    }
    sso = self.get_sso(platform, operation);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    return await sso.initiate_auth(operation);
}

impl JacScaleUserManager.sso_callback(
    request: Request, platform: str, operation: str
) -> TransportResponse {
    import from jaclang.runtimelib.server { JsonValue }
    if (platform not in [p.value for p in Platforms]) {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    if (platform not in self.SUPPORTED_PLATFORMS) {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured. Please set SSO_{platform.upper()}_CLIENT_ID and SSO_{platform.upper()}_CLIENT_SECRET environment variables.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    if (operation not in [o.value for o in Operations]) {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=f"Invalid operation '{operation}'. Must be 'login' or 'register'",
            meta=Meta(extra={'http_status': 400})
        );
    }
    sso = self.get_sso(platform, operation);
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
        if (operation == Operations.LOGIN.value) {
            user = self.get_user(email);
            if not user {
                return TransportResponse.fail(
                    code='USER_NOT_FOUND',
                    message='User not found. Please register first.',
                    meta=Meta(extra={'http_status': 404})
                );
            }
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
        } elif (operation == Operations.REGISTER.value) {
            existing_user = self.get_user(email);
            if existing_user {
                return TransportResponse.fail(
                    code='USER_EXISTS',
                    message='User already exists. Please login instead.',
                    meta=Meta(extra={'http_status': 400})
                );
            }
            random_password = generate_random_password();
            result = self.create_user(email, random_password);
            if ('error' in result) {
                return TransportResponse.fail(
                    code='USER_CREATION_FAILED',
                    message=result.get('error', 'User creation failed'),
                    meta=Meta(extra={'http_status': 400})
                );
            }
            token = self.create_jwt_token(email);
            result['token'] = token;
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
    return TransportResponse.fail(
        code='UNKNOWN_ERROR',
        message='An unknown error occurred',
        meta=Meta(extra={'http_status': 500})
    );
}

# SSO Account Linking Methods
"""Link an SSO account to a user.

This allows users to have multiple SSO providers linked to their account.
"""
impl JacScaleUserManager.link_sso_account(
    user_id: str, platform: str, external_id: str, email: str
) -> dict[str, str] {
    self._ensure_connection();
    # Check if this SSO account is already linked to another user
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
    # Link the SSO account
    self._conn.execute(
        """
        INSERT INTO sso_accounts (user_id, platform, external_id, email)
        VALUES (?, ?, ?, ?)
        """,
        (user_id, platform, external_id, email)
    );
    self._conn.commit();
    return {
        'message': 'SSO account linked successfully',
        'user_id': user_id,
        'platform': platform
    };
}

"""Unlink an SSO account from a user."""
impl JacScaleUserManager.unlink_sso_account(
    user_id: str, platform: str
) -> dict[str, str] {
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

"""Get all SSO accounts linked to a user."""
impl JacScaleUserManager.get_sso_accounts(user_id: str) -> list[dict[str, str]] {
    self._ensure_connection();
    cursor = self._conn.execute(
        """
        SELECT platform, external_id, email, linked_at
        FROM sso_accounts
        WHERE user_id = ?
        ORDER BY linked_at DESC
        """,
        (user_id, )
    );
    accounts = [];
    for row in cursor.fetchall() {
        accounts.append(
            {
                'platform': row[0],
                'external_id': row[1],
                'email': row[2],
                'linked_at': row[3]
            }
        );
    }
    return accounts;
}

"""Find a user by their SSO account credentials.

This is used during SSO login to find the user associated with
an external SSO identity.
"""
impl JacScaleUserManager.get_user_by_sso(
    platform: str, external_id: str
) -> (dict[str, str] | None) {
    self._ensure_connection();
    cursor = self._conn.execute(
        """
        SELECT sa.user_id, u.token, u.root_id
        FROM sso_accounts sa
        JOIN users u ON sa.user_id = u.username
        WHERE sa.platform = ? AND sa.external_id = ?
        """,
        (platform, external_id)
    );
    row = cursor.fetchone();
    if not row {
        return None;
    }
    return {'email': row[0], 'token': row[1], 'root_id': row[2]};
}

# ============================================================================
# User Role and Admin Management Methods
# ============================================================================
"""Get user's role."""
impl JacScaleUserManager.get_user_role(username: str) -> (str | None) {
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT role FROM users WHERE username = ?", (username, )
    );
    row = cursor.fetchone();
    if not row {
        return None;
    }
    return row[0] or 'user';
}

"""Set user's role."""
impl JacScaleUserManager.set_user_role(username: str, role: str) -> dict[str, str] {
    import from jac_scale.user_manager { UserRole }
    # Validate role
    valid_roles = [r.value for r in UserRole];
    if role not in valid_roles {
        return {'error': f"Invalid role. Must be one of: {', '.join(valid_roles)}"};
    }
    self._ensure_connection();
    cursor = self._conn.execute(
        "UPDATE users SET role = ? WHERE username = ?", (role, username)
    );
    self._conn.commit();
    if cursor.rowcount == 0 {
        return {'error': 'User not found'};
    }
    return {'message': f"Role updated to '{role}'", 'username': username, 'role': role};
}

"""Check if user is an admin."""
impl JacScaleUserManager.is_admin(username: str) -> bool {
    role = self.get_user_role(username);
    return role == 'admin';
}

"""Check if user requires password reset."""
impl JacScaleUserManager.requires_password_reset(username: str) -> bool {
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT requires_password_reset FROM users WHERE username = ?", (username, )
    );
    row = cursor.fetchone();
    if not row {
        return False;
    }
    return bool(row[0]);
}

"""Set whether user requires password reset."""
impl JacScaleUserManager.set_requires_password_reset(
    username: str, requires_reset: bool
) -> dict[str, str] {
    self._ensure_connection();
    cursor = self._conn.execute(
        "UPDATE users SET requires_password_reset = ? WHERE username = ?",
        (1 if requires_reset else 0, username)
    );
    self._conn.commit();
    if cursor.rowcount == 0 {
        return {'error': 'User not found'};
    }
    return {'message': 'Password reset requirement updated', 'username': username};
}

"""Check if password is required for user (SSO users may not need password)."""
impl JacScaleUserManager.is_password_required(username: str) -> bool {
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

"""Set whether password is required for user."""
impl JacScaleUserManager.set_password_required(
    username: str, required: bool
) -> dict[str, str] {
    self._ensure_connection();
    cursor = self._conn.execute(
        "UPDATE users SET is_password_required = ? WHERE username = ?",
        (1 if required else 0, username)
    );
    self._conn.commit();
    if cursor.rowcount == 0 {
        return {'error': 'User not found'};
    }
    return {'message': 'Password requirement updated', 'username': username};
}

"""Bootstrap the admin user with UUID all zeros if it doesn't exist."""
impl JacScaleUserManager.bootstrap_admin_user -> dict[str, str] {
    import logging;
    logger = logging.getLogger(__name__);
    admin_config = get_scale_config().get_admin_config();
    if not admin_config.get('enabled', True) {
        return {'message': 'Admin portal is disabled'};
    }
    admin_username = admin_config.get('username', 'admin');
    admin_email = admin_config.get('email', 'admin@localhost');
    default_password = admin_config.get('default_password', 'changeme');
    require_reset = admin_config.get('require_password_reset', True);
    # Check if admin already exists
    existing_admin = self.get_user(admin_username);
    if existing_admin {
        # Ensure existing user has admin role
        current_role = self.get_user_role(admin_username);
        if current_role != 'admin' {
            self._ensure_connection();
            self._conn.execute(
                "UPDATE users SET role = 'admin', user_id = ? WHERE username = ?",
                (self.ADMIN_USER_ID, admin_username)
            );
            self._conn.commit();
            logger.info(f"Existing user '{admin_username}' promoted to admin role");
        }
        return {'message': 'Admin user already exists', 'username': admin_username};
    }
    # Create admin user
    result = self.create_user(admin_username, default_password);
    if 'error' in result {
        return result;
    }
    # Set admin role and user_id
    self._ensure_connection();
    self._conn.execute(
        """
        UPDATE users
        SET role = 'admin',
            user_id = ?,
            requires_password_reset = ?
        WHERE username = ?
        """,
        (self.ADMIN_USER_ID, 1 if require_reset else 0, admin_username)
    );
    self._conn.commit();
    logger.warning(
        f"Admin user '{admin_username}' created with default password. "
        "Please change the password immediately!"
    );
    return {
        'message': 'Admin user created successfully',
        'username': admin_username,
        'user_id': self.ADMIN_USER_ID,
        'requires_password_reset': str(require_reset)
    };
}

"""List all users (admin only)."""
impl JacScaleUserManager.list_all_users(
    limit: int = 100, offset: int = 0
) -> list[dict[str, Any]] {
    self._ensure_connection();
    cursor = self._conn.execute(
        """
        SELECT username, root_id, role, requires_password_reset, is_password_required, user_id
        FROM users
        WHERE username != '__guest__'
        ORDER BY username
        LIMIT ? OFFSET ?
        """,
        (limit, offset)
    );
    users = [];
    for row in cursor.fetchall() {
        users.append(
            {
                'username': row[0],
                'root_id': row[1],
                'role': row[2] or 'user',
                'requires_password_reset': bool(row[3]),
                'is_password_required': bool(row[4]) if row[4] is not None else True,
                'user_id': row[5]
            }
        );
    }
    return users;
}

"""Delete a user (admin only)."""
impl JacScaleUserManager.delete_user(username: str) -> dict[str, str] {
    # Prevent deleting admin user with all-zeros UUID
    self._ensure_connection();
    cursor = self._conn.execute(
        "SELECT user_id FROM users WHERE username = ?", (username, )
    );
    row = cursor.fetchone();
    if row and row[0] == self.ADMIN_USER_ID {
        return {'error': 'Cannot delete the primary admin user'};
    }
    # Delete the user
    cursor = self._conn.execute("DELETE FROM users WHERE username = ?", (username, ));
    self._conn.commit();
    if cursor.rowcount == 0 {
        return {'error': 'User not found'};
    }
    return {'message': 'User deleted successfully', 'username': username};
}

"""Create a user as admin (sets requires_password_reset by default)."""
impl JacScaleUserManager.create_user_as_admin(
    username: str,
    password: str,
    role: str = 'user',
    requires_password_reset: bool = True
) -> dict[str, Any] {
    import from jac_scale.user_manager { UserRole }
    import uuid;
    # Validate role
    valid_roles = [r.value for r in UserRole];
    if role not in valid_roles {
        return {'error': f"Invalid role. Must be one of: {', '.join(valid_roles)}"};
    }
    # Create the base user
    result = self.create_user(username, password);
    if 'error' in result {
        return result;
    }
    # Update with admin-specific fields
    user_id = str(uuid.uuid4());
    self._ensure_connection();
    self._conn.execute(
        """
        UPDATE users
        SET role = ?,
            user_id = ?,
            requires_password_reset = ?
        WHERE username = ?
        """,
        (role, user_id, 1 if requires_password_reset else 0, username)
    );
    self._conn.commit();
    result['role'] = role;
    result['user_id'] = user_id;
    result['requires_password_reset'] = str(requires_password_reset);
    return result;
}
