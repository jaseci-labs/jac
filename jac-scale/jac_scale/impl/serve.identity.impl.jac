"""User identity & password-reset endpoints.

- POST /user/add-identity      (auth) - attach a new identity (e.g. email) to
                               the calling user. No email is sent; email
                               identities are stored as verified=False.
- POST /user/send-verification (auth) - issue a verification token for an
                               unverified email identity on the current user
                               and deliver it. Idempotent: returns
                               'already_verified' if the identity is verified.
- POST /user/verify-identity          - consume a verification token and flip
                               the matching identity to verified=True.
- POST /user/forgot-password          - issue a one-time reset token to the
                               email address tied to the identity, if any.
                               Always returns 200 (never leaks existence).
- POST /user/reset-password           - consume a reset token and set a new
                               password.
"""

import from jac_scale.auth_tokens { AuthTokenStore }
import from jac_scale.utils { authenticate_or_fail }

# ============================================================================
# /user/add-identity  (requires Bearer token)
# ============================================================================
impl JacAPIServerAuth.register_add_identity_endpoint -> None {
    async def add_identity_handler(
        request: Request, body_data: AddIdentityRequest
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        (user_id, auth_err) = authenticate_or_fail(
            authorization, self.user_manager, 'Invalid or expired token'
        );
        if auth_err is not None {
            return auth_err;
        }
        identity = body_data.identity.model_dump(mode='json');
        id_type = identity.get('type', '');
        raw_value = identity.get('value', '');
        normalized = raw_value.lower().strip();
        if not normalized {
            return TransportResponse.fail(
                code='VALIDATION_ERROR',
                message='Identity value is required',
                meta=Meta(extra={'http_status': 400})
            );
        }
        # Reject if any user already owns this identity.
        if self.user_manager.is_identity_taken(normalized) {
            return TransportResponse.fail(
                code='IDENTITY_TAKEN',
                message=f"This {id_type} is already registered",
                meta=Meta(extra={'http_status': 409})
            );
        }
        identity_doc = {
            'type': id_type,
            'value_raw': raw_value,
            'value_normalized': normalized,
            'verified': False,
            'is_recovery': bool(body_data.is_recovery)
        };
        if not self.user_manager.add_identity(user_id, identity_doc) {
            return TransportResponse.fail(
                code='NOT_FOUND',
                message='User not found',
                meta=Meta(extra={'http_status': 404})
            );
        }
        return TransportResponse.success(
            data={'status': 'added', 'verified': False},
            meta=Meta(extra={'http_status': 200})
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/add-identity',
            callback=add_identity_handler,
            request_model=AddIdentityRequest,
            response_model=None,
            tags=['User APIs'],
            summary='Attach a new identity to the authenticated user',
            description='Attaches an identity (e.g. email or username) to the user. Email identities are stored as unverified; use /user/send-verification to dispatch a verification mail.'
        )
    );
}

# ============================================================================
# /user/send-verification  (requires Bearer token)
# ============================================================================
impl JacAPIServerAuth.register_send_verification_endpoint -> None {
    async def send_verification_handler(
        request: Request, body_data: SendVerificationRequest
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        (user_id, auth_err) = authenticate_or_fail(
            authorization, self.user_manager, 'Invalid or expired token'
        );
        if auth_err is not None {
            return auth_err;
        }
        identity = body_data.identity.model_dump(mode='json');
        id_type = identity.get('type', '');
        raw_value = identity.get('value', '');
        normalized = (raw_value or '').lower().strip();
        if id_type != 'email' or not normalized {
            return TransportResponse.fail(
                code='VALIDATION_ERROR',
                message='An email identity value is required',
                meta=Meta(extra={'http_status': 400})
            );
        }
        user = self.user_manager.get_user(user_id);
        if user is None {
            return TransportResponse.fail(
                code='NOT_FOUND',
                message='User not found',
                meta=Meta(extra={'http_status': 404})
            );
        }
        # Find the requested identity on this user.
        target: dict[str, Any] | None = None;
        for ident in user.get('identities', []) {
            if ident.get('type') != 'email' {
                continue;
            }
            if (ident.get('value_normalized') or '') == normalized {
                target = ident;
                break;
            }
        }
        if target is None {
            return TransportResponse.fail(
                code='NOT_FOUND',
                message='Identity not found on this user',
                meta=Meta(extra={'http_status': 404})
            );
        }
        if target.get('verified') {
            return TransportResponse.success(
                data={'status': 'already_verified'},
                meta=Meta(extra={'http_status': 200})
            );
        }
        emailer = self.get_emailer();
        if emailer is None or not emailer.is_ready() {
            return TransportResponse.fail(
                code='EMAIL_DISABLED',
                message='Email features are not configured on this server',
                meta=Meta(extra={'http_status': 503})
            );
        }
        # Revoke any outstanding verify tokens for this user before issuing a
        # fresh one — keeps "resend" idempotent and prevents token reuse races.
        AuthTokenStore.instance().revoke_user_tokens(user_id, 'verify');
        auth_cfg = get_scale_config().get_auth_config();
        ttl = auth_cfg.get('verify_token_ttl_seconds', 86400);
        url_template = auth_cfg.get('verify_url_template', '');
        token = AuthTokenStore.instance().create_token(
            user_id=user_id,
            purpose='verify',
            ttl_seconds=ttl,
            identity_value=normalized
        );
        link = url_template.replace('{token}', token) if url_template else token;
        body_text = (
            f"Hello,\n\nUse the link below to verify your email address:\n\n"
            f"{link}\n\nThis link expires in {ttl // 60} minutes.\n\n"
            "If you did not request this, you can ignore this message."
        );
        recipient = target.get('value_raw') or raw_value;
        sent = emailer.send_email(
            to_addr=recipient, subject='Verify your email address', body_text=body_text
        );
        return TransportResponse.success(
            data={'status': 'pending_verification', 'email_sent': bool(sent)},
            meta=Meta(extra={'http_status': 202})
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/send-verification',
            callback=send_verification_handler,
            request_model=SendVerificationRequest,
            response_model=None,
            tags=['User APIs'],
            summary='Send a verification email for an unverified identity',
            description='Issues a verification token for an email identity on the authenticated user and delivers it via the configured emailer. Idempotent: returns already_verified if the identity is verified.'
        )
    );
}

# ============================================================================
# /user/verify-identity  (no auth - token is the credential)
# ============================================================================
impl JacAPIServerAuth.register_verify_identity_endpoint -> None {
    async def verify_identity_handler(
        body_data: VerifyIdentityRequest
    ) -> TransportResponse {
        record = AuthTokenStore.instance().consume_token(body_data.token, 'verify');
        if record is None {
            return TransportResponse.fail(
                code='INVALID_TOKEN',
                message='Verification token is invalid or expired',
                meta=Meta(extra={'http_status': 400})
            );
        }
        user_id = record.get('user_id', '');
        identity_value = record.get('identity_value', '') or '';
        if not user_id or not identity_value {
            return TransportResponse.fail(
                code='INVALID_TOKEN',
                message='Verification token is invalid',
                meta=Meta(extra={'http_status': 400})
            );
        }
        ok = self.user_manager.set_identity_verified(user_id, identity_value);
        if not ok {
            return TransportResponse.fail(
                code='NOT_FOUND',
                message='Identity not found for user',
                meta=Meta(extra={'http_status': 404})
            );
        }
        return TransportResponse.success(
            data={'status': 'verified', 'identity': identity_value},
            meta=Meta(extra={'http_status': 200})
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/verify-identity',
            callback=verify_identity_handler,
            request_model=VerifyIdentityRequest,
            response_model=None,
            tags=['User APIs'],
            summary='Verify an identity using a token from email',
            description='Marks the identity attached to the token as verified.'
        )
    );
}

# ============================================================================
# /user/forgot-password  (always returns 200 - never leaks account existence)
# ============================================================================
impl JacAPIServerAuth.register_forgot_password_endpoint -> None {
    async def forgot_password_handler(
        body_data: ForgotPasswordRequest
    ) -> TransportResponse {
        identity = body_data.identity.model_dump(mode='json');
        normalized = (identity.get('value', '') or '').lower().strip();
        ok_response = TransportResponse.success(
            data={
                'status': 'ok',
                'message': 'If that account exists, a reset link has been sent.'
            },
            meta=Meta(extra={'http_status': 200})
        );
        if not normalized {
            return ok_response;
        }
        emailer = self.get_emailer();
        if emailer is None or not emailer.is_ready() {
            logger.warning(
                "/user/forgot-password called but emailer is not configured"
            );
            return ok_response;
        }
        user = self.user_manager.find_user_by_identity(normalized);
        if user is None {
            return ok_response;
        }
        # Pick the recipient email: prefer a verified is_recovery identity, else
        # any verified email, else nothing (we still return ok_response).
        recipient_raw: (str | None) = None;
        recipient_normalized: (str | None) = None;
        for ident in user.get('identities', []) {
            if ident.get('type') != 'email' {
                continue;
            }
            if not ident.get('verified') {
                continue;
            }
            if ident.get('is_recovery') {
                recipient_raw = ident.get('value_raw');
                recipient_normalized = ident.get('value_normalized');
                break;
            }
            if recipient_raw is None {
                recipient_raw = ident.get('value_raw');
                recipient_normalized = ident.get('value_normalized');
            }
        }
        if not recipient_raw {
            return ok_response;
        }
        auth_cfg = get_scale_config().get_auth_config();
        ttl = auth_cfg.get('reset_token_ttl_seconds', 1800);
        url_template = auth_cfg.get('reset_url_template', '');
        # Invalidate prior outstanding reset tokens for this user.
        AuthTokenStore.instance().revoke_user_tokens(user.get('user_id', ''), 'reset');
        token = AuthTokenStore.instance().create_token(
            user_id=user.get('user_id', ''),
            purpose='reset',
            ttl_seconds=ttl,
            identity_value=recipient_normalized
        );
        link = url_template.replace('{token}', token) if url_template else token;
        body_text = (
            f"Hello,\n\nUse the link below to reset your password:\n\n"
            f"{link}\n\nThis link expires in {ttl // 60} minutes.\n\n"
            "If you did not request this, you can ignore this message - your "
            "password will remain unchanged."
        );
        emailer.send_email(
            to_addr=recipient_raw, subject='Reset your password', body_text=body_text
        );
        return ok_response;
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/forgot-password',
            callback=forgot_password_handler,
            request_model=ForgotPasswordRequest,
            response_model=None,
            tags=['User APIs'],
            summary='Start a password reset flow',
            description='Sends a reset link to the user\'s recovery email if the account exists. Always returns 200 to avoid leaking account existence.'
        )
    );
}

# ============================================================================
# /user/reset-password  (token-authenticated)
# ============================================================================
impl JacAPIServerAuth.register_reset_password_endpoint -> None {
    async def reset_password_handler(
        body_data: ResetPasswordRequest
    ) -> TransportResponse {
        record = AuthTokenStore.instance().consume_token(body_data.token, 'reset');
        if record is None {
            return TransportResponse.fail(
                code='INVALID_TOKEN',
                message='Reset token is invalid or expired',
                meta=Meta(extra={'http_status': 400})
            );
        }
        user_id = record.get('user_id', '');
        if not user_id {
            return TransportResponse.fail(
                code='INVALID_TOKEN',
                message='Reset token is invalid',
                meta=Meta(extra={'http_status': 400})
            );
        }
        self.user_manager.reset_password_by_user_id(user_id, body_data.new_password);
        # Drop any other outstanding reset tokens for this user.
        AuthTokenStore.instance().revoke_user_tokens(user_id, 'reset');
        return TransportResponse.success(
            data={'status': 'password_reset'}, meta=Meta(extra={'http_status': 200})
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/reset-password',
            callback=reset_password_handler,
            request_model=ResetPasswordRequest,
            response_model=None,
            tags=['User APIs'],
            summary='Reset password using a token',
            description='Sets a new password after verifying the reset token from /user/forgot-password.'
        )
    );
}
