# ============================================================================
# Entry point — registers all auth endpoints
# ============================================================================
impl JacAPIServerAuth.register_auth_endpoints -> None {
    self.register_register_endpoint();
    self.register_login_endpoint();
    self.register_refresh_token_endpoint();
    self.register_update_password_endpoint();
    self.register_me_endpoint();
    self.register_sso_endpoints();
    self.register_api_key_endpoints();
}

# ============================================================================
# Register (identity-based)
# ============================================================================
impl JacAPIServerAuth.register_register_endpoint -> None {
    def register_handler(body_data: RegisterRequest) -> TransportResponse {
        identities = [i.model_dump(mode='json') for i in body_data.identities];
        credential = body_data.credential.model_dump(mode='json');
        try {
            profile = validate_profile(body_data.profile);
        } except ValueError as ve {
            return TransportResponse.fail(
                code='VALIDATION_ERROR',
                message=str(ve),
                meta=Meta(extra={'http_status': 400})
            );
        }
        try {
            result = self.user_manager.create_user(identities, credential, profile);
            if 'error' in result {
                return TransportResponse.fail(
                    code=result.get('code', 'REGISTRATION_FAILED'),
                    message=result.get('error', 'Registration failed'),
                    meta=Meta(extra={'http_status': 400})
                );
            }
            return TransportResponse.success(
                data=result, meta=Meta(extra={'http_status': 201})
            );
        } except Exception as e {
            error_trace = traceback.format_exc();
            console.print(f"Error in register: {e}\n{error_trace}");
            return TransportResponse.fail(
                code='INTERNAL_ERROR',
                message='Registration failed',
                meta=Meta(extra={'http_status': 500})
            );
        }
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/register',
            callback=register_handler,
            request_model=RegisterRequest,
            response_model=None,
            tags=['User APIs'],
            summary='Register user',
            description='Create a new user with identities (username, email) and credential (password). No token returned — use /user/login to authenticate.'
        )
    );
}

# ============================================================================
# Login (identity-based)
# ============================================================================
impl JacAPIServerAuth.register_login_endpoint -> None {
    def login_handler(body_data: LoginRequest) -> TransportResponse {
        identifier = body_data.identity.value;
        password = body_data.credential.password;

        result = self.user_manager.authenticate(identifier, password);
        if not result {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Invalid credentials',
                meta=Meta(extra={'http_status': 401})
            );
        }
        user_id = result.get('user_id', '');
        result['token'] = self.user_manager.create_jwt_token(user_id);
        return TransportResponse.success(
            data=dict[(str, JsonValue)](result), meta=Meta(extra={'http_status': 200})
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/login',
            callback=login_handler,
            request_model=LoginRequest,
            response_model=None,
            tags=['User APIs'],
            summary='User login',
            description='Authenticate with identity (username or email) and credential (password). Returns JWT token.'
        )
    );
}

# ============================================================================
# Refresh Token
# ============================================================================
impl JacAPIServerAuth.register_refresh_token_endpoint -> None {
    def refresh_token_handler(token: str | None = None) -> TransportResponse {
        if not token {
            return TransportResponse.fail(
                code='VALIDATION_ERROR',
                message='Token is required',
                meta=Meta(extra={'http_status': 400})
            );
        }
        if token.startswith('Bearer ') {
            token = token[7:];
        }
        new_token = self.user_manager.refresh_jwt_token(token);
        if not new_token {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Invalid or expired token',
                meta=Meta(extra={'http_status': 401})
            );
        }
        return TransportResponse.success(
            data={'token': new_token, 'message': 'Token refreshed successfully'},
            meta=Meta(extra={'http_status': 200})
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/refresh-token',
            callback=refresh_token_handler,
            parameters=[
                APIParameter(
                    name='token',
                    data_type='string',
                    required=True,
                    default=None,
                    description='JWT token to refresh (with or without Bearer prefix)',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['User APIs'],
            summary='Refresh JWT token',
            description='Refresh an existing JWT token. Token must be within the refresh window.'
        )
    );
}

# ============================================================================
# Update Password (uses JWT user_id, no username param needed)
# ============================================================================
impl JacAPIServerAuth.register_update_password_endpoint -> None {
    async def update_password_handler(
        request: Request, body_data: UpdatePasswordRequest
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        user_id = extract_bearer_token(authorization, self.user_manager);
        if not user_id {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Invalid or expired token',
                meta=Meta(extra={'http_status': 401})
            );
        }
        result = self.user_manager.update_password(
            user_id, body_data.current_password, body_data.new_password
        );
        if 'error' in result {
            return TransportResponse.fail(
                code='UPDATE_FAILED',
                message=result.get('error', 'Password update failed'),
                meta=Meta(extra={'http_status': 400})
            );
        }
        return TransportResponse.success(
            data=result, meta=Meta(extra={'http_status': 200})
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path='/user/password',
            callback=update_password_handler,
            request_model=UpdatePasswordRequest,
            response_model=None,
            tags=['User APIs'],
            summary='Update password',
            description='Update the authenticated user\'s password. Requires Bearer token.'
        )
    );
}

# ============================================================================
# Current user (/user/me) — returns the authenticated user's profile
# ============================================================================
impl JacAPIServerAuth.register_me_endpoint -> None {
    async def me_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        user_id = extract_bearer_token(authorization, self.user_manager);
        if not user_id {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Invalid or expired token',
                meta=Meta(extra={'http_status': 401})
            );
        }
        user = self.user_manager.get_user(user_id);
        if not user {
            return TransportResponse.fail(
                code='NOT_FOUND',
                message='User not found',
                meta=Meta(extra={'http_status': 404})
            );
        }
        # Strip credentials and other internal fields. Identities are
        # returned without value_normalized or external_id to keep the
        # response clean.
        identities_out = [];
        for ident in user.get('identities', []) {
            identity_out: dict[str, Any] = {
                'type': ident.get('type'),
                'verified': ident.get('verified', False),
                'is_recovery': ident.get('is_recovery', False)
            };
            if ident.get('type') == 'sso' {
                identity_out['provider'] = ident.get('provider');
            } else {
                identity_out['value'] = ident.get('value_raw');
            }
            identities_out.append(identity_out);
        }
        data = {
            'user_id': user.get('user_id'),
            'role': user.get('role', 'user'),
            'status': user.get('status', 'active'),
            'identities': identities_out,
            'profile': user.get('profile') or {},
            'created_at': user.get('created_at'),
            'updated_at': user.get('updated_at')
        };
        return TransportResponse.success(
            data=dict[(str, JsonValue)](data), meta=Meta(extra={'http_status': 200})
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/user/me',
            callback=me_handler,
            parameters=[],
            response_model=None,
            tags=['User APIs'],
            summary='Get current user',
            description='Returns the authenticated user\'s identities, role, and profile. Requires Bearer token.'
        )
    );
}

# ============================================================================
# SSO
# ============================================================================
impl JacAPIServerAuth._create_sso_callback_wrapper -> Callable[
    ...,
    (Response | TransportResponse)
] {
    async def sso_callback_wrapper(
        request: Request, platform: str
    ) -> (Response | TransportResponse) {
        result = await self.user_manager.sso_callback(request, platform);
        sso_config = get_scale_config().get_sso_config();
        frontend_url = sso_config.get('client_auth_callback_url', '');
        if not frontend_url {
            return result;
        }
        if result.ok {
            token = result.data.get('token', '') if result.data else '';
            return RedirectResponse(url=f"{frontend_url}?token={token}");
        } else {
            error_code = result.error.code if result.error else 'UNKNOWN_ERROR';
            message = result.error.message if result.error else 'Unknown error';
            return RedirectResponse(
                url=f"{frontend_url}?error={quote(error_code)}&message={quote(message)}"
            );
        }
    }
    return sso_callback_wrapper;
}

impl JacAPIServerAuth.register_sso_endpoints -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/sso/{platform}/{operation}',
            callback=self.user_manager.sso_initiate,
            parameters=[
                APIParameter(
                    name='platform',
                    data_type='string',
                    required=True,
                    default=None,
                    description='SSO platform: google, apple, github',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='operation',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Operation: "login" or "register"',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['SSO APIs'],
            summary='Initiate SSO authentication',
            description='Redirects to the SSO provider for authentication.'
        )
    );
    sso_callback_wrapper = self._create_sso_callback_wrapper();
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/sso/{platform}/callback',
            callback=sso_callback_wrapper,
            parameters=[
                APIParameter(
                    name='platform',
                    data_type='string',
                    required=True,
                    default=None,
                    description='SSO platform: google, apple, github',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['SSO APIs'],
            summary='SSO callback endpoint (GET)',
            description='Handles the callback from SSO provider after authentication.'
        )
    );
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/sso/{platform}/callback',
            callback=sso_callback_wrapper,
            parameters=[
                APIParameter(
                    name='platform',
                    data_type='string',
                    required=True,
                    default=None,
                    description='SSO platform: google, apple, github',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['SSO APIs'],
            summary='SSO callback endpoint (POST)',
            description='Handles POST callbacks from SSO providers like Apple Sign In.'
        )
    );
}

# ============================================================================
# API Key Management
# ============================================================================
impl JacAPIServerAuth.get_api_key_manager -> ApiKeyManager {
    if self._api_key_manager is None {
        self._api_key_manager = ApiKeyManager();
    }
    return self._api_key_manager;
}

impl JacAPIServerAuth.create_api_key(
    name: str, expiry_days: int | None = None, Authorization: str | None = None
) -> TransportResponse {
    user_id = extract_bearer_token(Authorization, self.user_manager);
    if not user_id {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Valid authentication required to create API keys',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return self.get_api_key_manager().create_api_key(
        username=user_id, name=name, expiry_days=expiry_days
    );
}

impl JacAPIServerAuth.list_api_keys(
    Authorization: str | None = None
) -> TransportResponse {
    user_id = extract_bearer_token(Authorization, self.user_manager);
    if not user_id {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Valid authentication required to list API keys',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return self.get_api_key_manager().list_api_keys(user_id);
}

impl JacAPIServerAuth.revoke_api_key(
    api_key_id: str, Authorization: str | None = None
) -> TransportResponse {
    user_id = extract_bearer_token(Authorization, self.user_manager);
    if not user_id {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Valid authentication required to revoke API keys',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return self.get_api_key_manager().revoke_api_key(user_id, api_key_id);
}

impl JacAPIServerAuth.register_api_key_endpoints -> None {
    async def create_api_key_handler(
        request: Request, name: str, expiry_days: int | None = None
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.create_api_key(name, expiry_days, authorization);
    }
    async def list_api_keys_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.list_api_keys(authorization);
    }
    async def revoke_api_key_handler(
        request: Request, api_key_id: str
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.revoke_api_key(api_key_id, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/api-key/create',
            callback=create_api_key_handler,
            parameters=[
                APIParameter(
                    name='name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='A friendly name for the API key',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='expiry_days',
                    data_type='integer',
                    required=False,
                    default=None,
                    description='Number of days until expiry (default from config)',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['API Keys'],
            summary='Create a new API key',
            description='Creates a new API key for webhook authentication.'
        )
    );
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/api-key/list',
            callback=list_api_keys_handler,
            parameters=[],
            response_model=None,
            tags=['API Keys'],
            summary='List all API keys',
            description='Lists all API keys for the authenticated user.'
        )
    );
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.DELETE,
            path='/api-key/{api_key_id}',
            callback=revoke_api_key_handler,
            parameters=[
                APIParameter(
                    name='api_key_id',
                    data_type='string',
                    required=True,
                    default=None,
                    description='The ID of the API key to revoke',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['API Keys'],
            summary='Revoke an API key',
            description='Revokes an API key, making it invalid for future requests.'
        )
    );
}
