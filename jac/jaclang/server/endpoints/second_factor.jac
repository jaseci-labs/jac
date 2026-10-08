import logging;
import from jaclang.server.endpoints.auth { fail, ok, throttled }
import from jaclang.server.identity.assurance {
    AAL1,
    AAL2,
    METHOD_PASSWORD,
    METHOD_TOTP,
    second_factor_claims,
    token_assurance
}
import from jaclang.server.identity.audit { client_ip, emit as audit }
import from jaclang.server.identity.auth_models {
    EnrollFactorRequest,
    RemoveFactorRequest,
    SecondFactorLoginRequest,
    VerifyFactorRequest
}
import from jaclang.server.identity.identity_storage { primary_username }
import from jaclang.server.identity.session_cookie { start_session }
import from jaclang.server.identity.second_factor {
    FACTOR_VERIFIED,
    SecondFactorUnavailable
}
import from jaclang.server.identity.user_manager { UserRole }
import from jaclang.server.middleware { bearer_token, require_user }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.server.server { EndpointHost, JsonValue }
import from jaclang.server.transport { TransportResponse }

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def unavailable -> TransportResponse {
    return fail(
        'SECOND_FACTOR_UNAVAILABLE',
        'Second factor verification is temporarily unavailable. Please try again.',
        503
    );
}


def refused(result: dict[str, any], proof_status: int) -> TransportResponse {
    code = str(result.get('code') or 'INVALID_CODE');
    if code == 'RATE_LIMITED' {
        return throttled(int(result.get('retry_after') or 1), 'Sign-in');
    }
    if code == 'NOT_FOUND' {
        return fail('NOT_FOUND', 'Factor not found', 404);
    }
    if code == 'FACTOR_LIMIT' {
        return fail(
            'FACTOR_LIMIT', 'This account has the maximum number of factors', 409
        );
    }
    if code == 'INVALID_PASSWORD' {
        return fail('INVALID_PASSWORD', 'Password is incorrect', proof_status);
    }
    if code == 'INVALID_CHALLENGE' {
        return fail(
            'INVALID_CHALLENGE', 'Sign-in challenge is invalid or expired', 401
        );
    }
    return fail('INVALID_CODE', 'Code is invalid or already used', proof_status);
}


def account_label(user: dict[str, any]) -> str {
    username = primary_username(user);
    if username {
        return username;
    }
    for identity in (user.get('identities') or []) {
        if isinstance(identity, dict) and identity.get('value_raw') {
            return str(identity.get('value_raw'));
        }
    }
    return str(user.get('user_id') or '');
}

def register_second_factor_endpoints(server: EndpointHost) {
    users = server.identity();

    def enroll_handler(
        request: Request, body_data: EnrollFactorRequest
    ) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        user = users.get_user(str(user_id));
        if not user {
            return fail('NOT_FOUND', 'User not found', 404);
        }
        try {
            result = users.second_factors().enroll(
                str(user_id),
                body_data.password,
                body_data.code,
                body_data.recovery_code,
                account_label(user)
            );
        } except SecondFactorUnavailable {
            return unavailable();
        }
        if not result.get('ok') {
            audit(
                'second_factor.enroll_refused',
                user_id=str(user_id),
                reason=str(result.get('code')),
                source_ip=client_ip(request)
            );
            return refused(result, 403);
        }
        audit(
            'second_factor.enrolled',
            user_id=str(user_id),
            factor_id=result['factor_id'],
            source_ip=client_ip(request)
        );
        return ok(
            {
                'factor_id': result['factor_id'],
                'type': 'totp',
                'status': 'unverified',
                'secret': result['secret'],
                'otpauth_uri': result['otpauth_uri']
            },
            status=201
        );
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/mfa/enroll',
            callback=enroll_handler,
            request_model=EnrollFactorRequest,
            tags=['User APIs'],
            summary='Start enrolling a TOTP second factor',
            description="Requires the account password, and a current code or recovery code when the account already has a verified factor. Answers the shared secret and an otpauth:// URI once; the factor does not count until /user/mfa/verify confirms it.",
            requires_auth=True
        )
    );

    def verify_handler(
        request: Request, body_data: VerifyFactorRequest
    ) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        try {
            result = users.second_factors().confirm(
                str(user_id), body_data.factor_id, body_data.code
            );
        } except SecondFactorUnavailable {
            return unavailable();
        }
        if not result.get('ok') {
            audit(
                'second_factor.verify_refused',
                user_id=str(user_id),
                reason=str(result.get('code')),
                source_ip=client_ip(request)
            );
            return refused(result, 403);
        }
        if result.get('activated') {
            audit(
                'second_factor.verified',
                user_id=str(user_id),
                factor_id=body_data.factor_id,
                source_ip=client_ip(request)
            );
        }
        prior = token_assurance(bearer_token(request)).get('amr') or [];
        payload: dict[str, any] = {
            'factor_id': body_data.factor_id,
            'status': FACTOR_VERIFIED,
            'assurance_level': AAL2,
            'token': users.create_jwt_token(
                str(user_id), assurance=second_factor_claims(prior + [METHOD_TOTP])
            )
        };
        if result.get('recovery_codes') {
            payload['recovery_codes'] = result['recovery_codes'];
        }
        start_session(request, str(payload['token']));
        return ok(payload);
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/mfa/verify',
            callback=verify_handler,
            request_model=VerifyFactorRequest,
            tags=['User APIs'],
            summary='Confirm a TOTP factor with a current code',
            description='Activates an unverified factor, or steps the session up when the factor is already verified. Answers a session token carrying aal2, and single-use recovery codes the first time a factor is activated.',
            requires_auth=True
        )
    );

    def factors_handler(request: Request) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        factors = users.second_factors().factors(str(user_id));
        enrolled = any(f['status'] == FACTOR_VERIFIED for f in factors);
        current = token_assurance(bearer_token(request));
        return ok(
            {
                'factors': factors,
                'current_level': AAL2 if current else AAL1,
                'next_level': AAL2 if enrolled else AAL1,
                'methods': current.get('amr') or []
            }
        );
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/user/mfa/factors',
            callback=factors_handler,
            parameters=[],
            tags=['User APIs'],
            summary='List second factors and the session assurance level',
            description="The authenticated user's factors (id, type, status, timestamps; never the secret), the assurance level of the session in use and the level the account can reach.",
            requires_auth=True
        )
    );

    def unenroll_handler(
        request: Request, body_data: RemoveFactorRequest
    ) -> TransportResponse {
        (user_id, error) = require_user(request);
        if error is not None {
            return error;
        }
        try {
            result = users.second_factors().remove(
                str(user_id),
                body_data.factor_id,
                body_data.code,
                body_data.recovery_code
            );
        } except SecondFactorUnavailable {
            return unavailable();
        }
        if not result.get('ok') {
            audit(
                'second_factor.remove_refused',
                user_id=str(user_id),
                reason=str(result.get('code')),
                source_ip=client_ip(request)
            );
            return refused(result, 403);
        }
        audit(
            'second_factor.removed',
            user_id=str(user_id),
            factor_id=body_data.factor_id,
            source_ip=client_ip(request)
        );
        return ok({'factor_id': body_data.factor_id, 'status': 'removed'});
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/mfa/unenroll',
            callback=unenroll_handler,
            request_model=RemoveFactorRequest,
            tags=['User APIs'],
            summary='Delete a second factor',
            description='Deleting a verified factor requires a current code from any verified factor, or a recovery code. An unverified factor is deleted with the session alone.',
            requires_auth=True
        )
    );

    def second_factor_login_handler(
        request: Request, body_data: SecondFactorLoginRequest
    ) -> TransportResponse {
        try {
            result = users.second_factors().complete_login(
                body_data.challenge_token, body_data.code, body_data.recovery_code
            );
        } except SecondFactorUnavailable {
            return unavailable();
        }
        if not result.get('ok') {
            audit(
                'second_factor.login_refused',
                user_id=str(result.get('user_id') or ''),
                reason=str(result.get('code')),
                source_ip=client_ip(request)
            );
            return refused(result, 401);
        }
        user_id = str(result['user_id']);
        user = users.get_user(user_id);
        if not user
            or str(user.get('status') or 'active') != 'active'
            or str(user.get('role') or 'user') == UserRole.SYSTEM.value {
            return fail('UNAUTHORIZED', 'Invalid credentials', 401);
        }
        audit(
            'second_factor.login',
            user_id=user_id,
            method=str(result['method']),
            source_ip=client_ip(request)
        );
        payload: dict[str, any] = {
            'user_id': user_id,
            'root_id': user.get('root_id'),
            'role': str(user.get('role') or 'user')
        };
        username = primary_username(user);
        if username {
            payload['username'] = username;
        }
        payload['token'] = users.create_jwt_token(
            user_id,
            assurance=second_factor_claims([METHOD_PASSWORD, str(result['method'])])
        );
        start_session(request, str(payload['token']));
        return ok(dict[(str, JsonValue)](payload));
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/mfa/login',
            callback=second_factor_login_handler,
            request_model=SecondFactorLoginRequest,
            tags=['User APIs'],
            summary='Finish sign-in with a second factor',
            description='Exchanges the challenge_token answered by /user/login, together with a current code or a recovery code, for a session token carrying aal2.'
        )
    );
}
