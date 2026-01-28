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
    self._conn.commit();
    # Load SSO config
    sso_config = get_scale_config().get_sso_config();
    for platform in Platforms {
        key = platform.lower();
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

impl JacScaleUserManager.create_jwt_token(username: str) -> str {
    now = datetime.now(UTC);
    payload: dict[(str, Any)] = {
        'username': username,
        'exp': (now + timedelta(days=JWT_EXP_DELTA_DAYS)),
        'iat': now.timestamp()
    };
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM);
}

impl JacScaleUserManager.validate_jwt_token(token: str) -> (str | None) {
    try {
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
        return decoded['username'];
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
