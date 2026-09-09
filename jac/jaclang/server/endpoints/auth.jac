import logging;
import from jaclang.server.identity.rate_limit { consume_limit }
import traceback;
import from jaclang.server.identity.config { auth_settings }
import from jaclang.server.identity.registration_challenge {
    issue_challenge,
    consume_challenge
}
import from jaclang.server.identity.audit { client_ip, emit as audit }
import from jaclang.server.identity.auth_models {
    AddIdentityRequest,
    LoginRequest,
    MeIdentity,
    MeResponse,
    RegisterRequest,
    ResetPasswordRequest,
    UpdatePasswordRequest,
    UpdateProfileRequest,
    UpdateProfileResponse,
    UpdateUsernameRequest,
    VerifyIdentityRequest
}
import from jaclang.server.identity.auth_tokens { AuthTokenStore }
import from jaclang.server.identity.identity_storage {
    IdentityTakenError,
    primary_username
}
import from jaclang.server.identity.user_manager { UserRole }
import from jaclang.server.middleware { require_user }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.server.server { EndpointHost, JsonValue }
import from jaclang.server.transport { Meta, TransportResponse }

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def fail(
    code: str, message: str, status: int, extra: (dict[str, any] | None) = None
) -> TransportResponse {
    meta_extra: dict[str, any] = {'http_status': status};
    if extra {
        meta_extra.update(extra);
    }
    return TransportResponse.fail(
        code=code, message=message, meta=Meta(extra=meta_extra)
    );
}


def ok(
    data: dict[str, any], status: int = 200, extra: (dict[str, any] | None) = None
) -> TransportResponse {
    meta_extra: dict[str, any] = {'http_status': status};
    if extra {
        meta_extra.update(extra);
    }
    return TransportResponse.success(data=data, meta=Meta(extra=meta_extra));
}


def normalize_identity(identity_input: any) -> tuple[str, str, str] {
    identity = identity_input.model_dump(mode='json');
    id_type = identity.get('type', '');
    raw_value = identity.get('value', '') or '';
    return (id_type, raw_value, raw_value.lower().strip());
}


def registration_limit(
    request: Request, scope: str, cap: int, seconds: int
) -> TransportResponse | None {
    retry = consume_limit(scope, client_ip(request), cap, seconds);
    if retry < 0 {
        return fail(
            'LIMIT_UNAVAILABLE',
            'Registration is temporarily unavailable. Please try again.',
            503
        );
    }
    if retry > 0 {
        return fail(
            'RATE_LIMITED',
            f"Too many attempts. Try again in {retry} seconds.",
            429,
            {'retry_after_seconds': retry}
        );
    }
    return None;
}

def register_auth_endpoints(server: EndpointHost) {
    users = server.identity();

    def challenge_handler(request: Request) -> TransportResponse {
        if not auth_settings().registration_challenge {
            return ok({'required': False});
        }
        limited = registration_limit(
            request,
            'registration-challenge',
            auth_settings().registration_challenges_per_10_minutes,
            600
        );
        if limited is not None {
            return limited;
        }
        try {
            return ok({'required': True, 'challenge': issue_challenge()});
        } except Exception {
            return fail(
                'CHALLENGE_UNAVAILABLE',
                'Verification is unavailable. Please try again.',
                503
            );
        }
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/register/challenge',
            callback=challenge_handler,
            tags=['User APIs'],
            summary='Registration challenge'
        )
    );

    def register_handler(
        body_data: RegisterRequest, request: Request
    ) -> TransportResponse {
        limited = registration_limit(
            request,
            'registration-attempt',
            auth_settings().registration_attempts_per_hour,
            3600
        );
        if limited is not None {
            return limited;
        }
        if auth_settings().registration_challenge {
            try {
                verified = consume_challenge(body_data.challenge);
            } except Exception {
                return fail(
                    'CHALLENGE_UNAVAILABLE',
                    'Verification is unavailable. Please try again.',
                    503
                );
            }
            if not verified {
                return fail(
                    'CHALLENGE_REQUIRED',
                    'Complete a fresh registration verification and try again.',
                    400
                );
            }
        }
        identities = [i.model_dump(mode='json') for i in body_data.identities];
        credential = body_data.credential.model_dump(mode='json');
        try {
            result = users.create_user_with_identities(
                identities, credential, body_data.profile
            );
        } except Exception as e {
            logger.error(f"register failed: {e}\n{traceback.format_exc()}");
            return fail('INTERNAL_ERROR', 'Registration failed', 500);
        }
        if 'error' in result {
            return fail(
                result.get('code', 'REGISTRATION_FAILED'),
                result.get('error', 'Registration failed'),
                400
            );
        }
        result['token'] = users.create_jwt_token(str(result.get('user_id', '')));
        return ok(result, status=201);
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/register',
            callback=register_handler,
            request_model=RegisterRequest,
            tags=['User APIs'],
            summary='Register user',
            description='Create a user with identities (username, email) and a password credential. Answers the new user id, root id and a session token.'
        )
    );

    def login_handler(body_data: LoginRequest) -> TransportResponse {
        result = users.authenticate(
            body_data.identity.value, body_data.credential.password
        );
        if not result {
            return fail('UNAUTHORIZED', 'Invalid credentials', 401);
        }
        user_id = result.get('user_id', '');
        if users.get_user_role(user_id) == UserRole.SYSTEM.value {
            return fail('UNAUTHORIZED', 'Invalid credentials', 401);
        }
        result['token'] = users.create_jwt_token(user_id);
        return ok(dict[(str, JsonValue)](result));
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/login',
            callback=login_handler,
            request_model=LoginRequest,
            tags=['User APIs'],
            summary='User login',
            description='Authenticate with an identity (username or email) and password. Returns a JWT.'
        )
    );

    def refresh_token_handler(token: (str | None) = None) -> TransportResponse {
        if not token {
            return fail('VALIDATION_ERROR', 'Token is required', 400);
        }
        if token.startswith('Bearer ') {
            token = token[7:];
        }
        claims = users.get_jwt_claims(token);
        if claims and claims.get('role') == UserRole.SYSTEM.value {
            return fail('UNAUTHORIZED', 'Invalid or expired token', 401);
        }
        new_token = users.refresh_jwt_token(token);
        if not new_token {
            return fail('UNAUTHORIZED', 'Invalid or expired token', 401);
        }
        return ok({'token': new_token, 'message': 'Token refreshed successfully'});
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/refresh-token',
            callback=refresh_token_handler,
            parameters=[
                APIParameter(
                    name='token',
                    data_type='string',
                    required=True,
                    description='JWT to refresh (with or without the Bearer prefix)',
                    kind=ParameterType.BODY
                )
            ],
            tags=['User APIs'],
            summary='Refresh JWT token',
            description='Exchange a still-valid token for a fresh one.'
        )
    );

    async def update_password_handler(
        request: Request, body_data: UpdatePasswordRequest
    ) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        if body_data.username {
            owner = users.find_user_by_identity(body_data.username);
            if owner is None or str(owner.get('user_id') or '') != str(user_id) {
                return fail('FORBIDDEN', "Cannot update another user's password", 403);
            }
        }
        result = users.update_password(
            str(user_id), body_data.current_password, body_data.new_password
        );
        if 'error' in result {
            return fail(
                'UPDATE_FAILED', result.get('error', 'Password update failed'), 400
            );
        }
        payload: dict[str, any] = dict(result);
        payload['user_id'] = str(user_id);
        username = primary_username(users.get_user(str(user_id)) or {});
        if username {
            payload['username'] = username;
        }
        return ok(payload);
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path='/user/password',
            callback=update_password_handler,
            request_model=UpdatePasswordRequest,
            tags=['User APIs'],
            summary='Update password',
            description="Change the authenticated user's password. Requires a Bearer token.",
            requires_auth=True
        )
    );

    async def update_username_handler(
        request: Request, body_data: UpdateUsernameRequest
    ) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        current = primary_username(users.get_user(str(user_id)) or {});
        if body_data.current_username
            and body_data.current_username.lower().strip() != current.lower().strip() {
            return fail('FORBIDDEN', "Cannot update another user's username", 403);
        }
        result = users.rename_username(str(user_id), body_data.new_username);
        if 'error' in result {
            code = str(result.get('code') or 'UPDATE_FAILED');
            status = 400;
            if code == 'NOT_FOUND' {
                status = 404;
            }
            return fail(code, result.get('error', 'Username update failed'), status);
        }
        result['token'] = users.create_jwt_token(str(user_id));
        return ok(result);
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path='/user/username',
            callback=update_username_handler,
            request_model=UpdateUsernameRequest,
            tags=['User APIs'],
            summary='Update username',
            description="Replace the authenticated user's username identity. Requires a Bearer token.",
            requires_auth=True
        )
    );

    async def user_info_handler(request: Request) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        user = users.get_user(str(user_id));
        if not user {
            return fail('NOT_FOUND', 'User not found', 404);
        }
        auth_header = str(request.headers.get('Authorization') or '');
        token = auth_header[7:] if auth_header.startswith('Bearer ') else auth_header;
        info: dict[str, any] = {
            'user_id': str(user.get('user_id') or ''),
            'root_id': str(user.get('root_id') or ''),
            'role': str(user.get('role') or 'user'),
            'token': token
        };
        username = primary_username(user);
        if username {
            info['username'] = username;
        }
        return ok(info);
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/user/info',
            callback=user_info_handler,
            parameters=[],
            tags=['User APIs'],
            summary='Get user info',
            description="The authenticated user's id, username, root id and the session token in use. Requires a Bearer token.",
            requires_auth=True
        )
    );

    async def me_handler(request: Request) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        user = users.get_user(str(user_id));
        if not user {
            return fail('NOT_FOUND', 'User not found', 404);
        }
        identities_out: list[MeIdentity] = [];
        for ident in user.get('identities', []) {
            kind = str(ident.get('type') or '');
            identities_out.append(
                MeIdentity(
                    type=kind,
                    verified=bool(ident.get('verified', False)),
                    is_recovery=bool(ident.get('is_recovery', False)),
                    value=None if kind == 'sso' else ident.get('value_raw'),
                    provider=ident.get('provider') if kind == 'sso' else None
                )
            );
        }
        me = MeResponse(
            user_id=str(user.get('user_id') or ''),
            role=str(user.get('role') or 'user'),
            status=str(user.get('status') or 'active'),
            identities=identities_out,
            profile=user.get('profile') or {},
            created_at=user.get('created_at'),
            updated_at=user.get('updated_at')
        );
        return ok(me.model_dump(mode='json', exclude_none=True));
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/user/me',
            callback=me_handler,
            parameters=[],
            response_model=MeResponse,
            tags=['User APIs'],
            summary='Get current user',
            description="The authenticated user's identities, role and profile. Requires a Bearer token.",
            requires_auth=True
        )
    );

    async def update_me_handler(
        request: Request, body_data: UpdateProfileRequest
    ) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        result = users.update_profile(str(user_id), body_data.profile);
        if 'error' in result {
            err_msg = result.get('error', 'Profile update failed');
            status = 404 if err_msg == 'User not found' else 400;
            return fail(
                'NOT_FOUND' if status == 404 else 'UPDATE_FAILED', err_msg, status
            );
        }
        response = UpdateProfileResponse(
            message='Profile updated', profile=result.get('profile') or {}
        );
        return ok(response.model_dump(mode='json'));
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PATCH,
            path='/user/me',
            callback=update_me_handler,
            request_model=UpdateProfileRequest,
            response_model=UpdateProfileResponse,
            tags=['User APIs'],
            summary='Update current user profile',
            description="Merge the supplied fields into the authenticated user's profile. Requires a Bearer token.",
            requires_auth=True
        )
    );

    async def add_identity_handler(
        request: Request, body_data: AddIdentityRequest
    ) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        (id_type, raw_value, normalized) = normalize_identity(body_data.identity);
        if not normalized {
            return fail('VALIDATION_ERROR', 'Identity value is required', 400);
        }
        taken_msg = f"This {id_type} is already registered";
        if users.is_identity_taken(normalized) {
            return fail('IDENTITY_TAKEN', taken_msg, 409);
        }
        identity_doc = {
            'type': id_type,
            'value_raw': raw_value,
            'value_normalized': normalized,
            'verified': False,
            'is_recovery': bool(body_data.is_recovery)
        };
        try {
            added = users.add_identity(str(user_id), identity_doc);
        } except IdentityTakenError {
            return fail('IDENTITY_TAKEN', taken_msg, 409);
        }
        if not added {
            return fail('NOT_FOUND', 'User not found', 404);
        }
        return ok({'status': 'added', 'verified': False});
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/add-identity',
            callback=add_identity_handler,
            request_model=AddIdentityRequest,
            tags=['User APIs'],
            summary='Attach a new identity to the authenticated user',
            description='Attach a username or email identity. Email identities start unverified; /user/send-verification mails a verification link when a mail channel is configured.',
            requires_auth=True
        )
    );

    async def verify_identity_handler(
        request: Request, body_data: VerifyIdentityRequest
    ) -> TransportResponse {
        source_ip = client_ip(request);
        record = AuthTokenStore.instance().consume_token(body_data.token, 'verify');
        if record is None {
            audit(
                'identity_verification.failed',
                reason='invalid_or_expired_token',
                source_ip=source_ip
            );
            return fail(
                'INVALID_TOKEN', 'Verification token is invalid or expired', 400
            );
        }
        user_id = record.get('user_id', '');
        identity_value = record.get('identity_value', '') or '';
        if not user_id or not identity_value {
            audit(
                'identity_verification.failed',
                reason='token_missing_fields',
                source_ip=source_ip
            );
            return fail('INVALID_TOKEN', 'Verification token is invalid', 400);
        }
        flipped = users.set_identity_verified(user_id, identity_value);
        if not flipped {
            user = users.get_user(user_id);
            if user is not None {
                for ident in user.get('identities', []) {
                    if (ident.get('value_normalized') or '') == identity_value
                        and ident.get('verified') {
                        audit(
                            'identity_verification.already_verified',
                            user_id=user_id,
                            identity_value=identity_value,
                            source_ip=source_ip
                        );
                        return ok(
                            {'status': 'already_verified', 'identity': identity_value}
                        );
                    }
                }
            }
            audit(
                'identity_verification.failed',
                reason='identity_not_found',
                user_id=user_id,
                identity_value=identity_value,
                source_ip=source_ip
            );
            return fail('NOT_FOUND', 'Identity not found for user', 404);
        }
        audit(
            'identity_verification.completed',
            user_id=user_id,
            identity_value=identity_value,
            source_ip=source_ip
        );
        return ok({'status': 'verified', 'identity': identity_value});
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/verify-identity',
            callback=verify_identity_handler,
            request_model=VerifyIdentityRequest,
            tags=['User APIs'],
            summary='Verify an identity using a token from email',
            description='Marks the identity attached to the token as verified.'
        )
    );

    async def reset_password_handler(
        request: Request, body_data: ResetPasswordRequest
    ) -> TransportResponse {
        source_ip = client_ip(request);
        record = AuthTokenStore.instance().consume_token(body_data.token, 'reset');
        if record is None {
            audit(
                'password_reset.failed',
                reason='invalid_or_expired_token',
                source_ip=source_ip
            );
            return fail('INVALID_TOKEN', 'Reset token is invalid or expired', 400);
        }
        user_id = record.get('user_id', '');
        identity_value = record.get('identity_value', '') or '';
        if not user_id {
            audit(
                'password_reset.failed',
                reason='token_missing_user',
                source_ip=source_ip
            );
            return fail('INVALID_TOKEN', 'Reset token is invalid', 400);
        }
        result = users.reset_password_by_user_id(user_id, body_data.new_password);
        if result.get('error') {
            audit(
                'password_reset.failed',
                reason='user_gone',
                user_id=user_id,
                identity_value=identity_value,
                source_ip=source_ip
            );
            return fail('NOT_FOUND', result.get('error', 'User not found'), 404);
        }
        AuthTokenStore.instance().revoke_user_tokens(user_id, 'reset');
        audit(
            'password_reset.completed',
            user_id=user_id,
            identity_value=identity_value,
            source_ip=source_ip
        );
        return ok({'status': 'password_reset'});
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/reset-password',
            callback=reset_password_handler,
            request_model=ResetPasswordRequest,
            tags=['User APIs'],
            summary='Reset password using a token',
            description='Sets a new password after verifying a reset token.'
        )
    );
}
