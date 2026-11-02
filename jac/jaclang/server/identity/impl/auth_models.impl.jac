impl validate_profile(profile: dict[str, any] | None) -> dict[str, any] | None {
    if profile is None {
        return None;
    }
    if not isinstance(profile, dict) {
        raise ValueError('profile must be an object');
    }
    if len(profile) > PROFILE_MAX_KEYS {
        raise ValueError(f'profile may have at most {PROFILE_MAX_KEYS} keys');
    }
    for (key, value) in profile.items() {
        if not isinstance(key, str) or not PROFILE_KEY_PATTERN.`match(key) {
            raise ValueError(
                f"profile contains an invalid key - keys must start with a letter and contain only letters, digits, and underscores (max {PROFILE_MAX_KEY_LENGTH} characters)"
            );
        }
        if key in PROFILE_RESERVED_KEYS {
            raise ValueError(
                f"profile['{key}'] is reserved for server use and cannot be set by clients"
            );
        }

        if not isinstance(value, (str, int, float)) {
            raise ValueError(f"profile['{key}'] must be a string, number, or boolean");
        }
        if isinstance(value, str) and len(value) > PROFILE_MAX_VALUE_LENGTH {
            raise ValueError(
                f"profile['{key}'] exceeds {PROFILE_MAX_VALUE_LENGTH} characters"
            );
        }
    }
    if len(json.dumps(profile).encode('utf-8')) > PROFILE_MAX_JSON_BYTES {
        raise ValueError(
            f'profile exceeds {PROFILE_MAX_JSON_BYTES} bytes when serialized'
        );
    }
    return profile;
}

impl IdentityInputModel.from_dict(data: any) -> IdentityInputModel {
    if not isinstance(data, dict) {
        raise ValueError('identity must be an object');
    }
    type_value = require_str(data, 'type', 'identity.type');
    if type_value not in IDENTITY_TYPES {
        raise ValueError("identity.type must be one of 'email' or 'username'");
    }
    value = require_str(data, 'value', 'identity.value');
    if type_value == 'email' and not EMAIL_PATTERN.`match(value) {
        raise ValueError('identity.value is not a valid email address');
    }
    return IdentityInputModel(type=type_value, value=value);
}

impl CredentialInput.from_dict(data: any) -> CredentialInput {
    if not isinstance(data, dict) {
        raise ValueError('credential must be an object');
    }
    type_value = require_str(data, 'type', 'credential.type');
    allowed = {member.value for member in CredentialType};
    if type_value not in allowed {
        raise ValueError(f"credential.type must be one of {sorted(allowed)}");
    }
    password = require_str(data, 'password', 'credential.password');
    return CredentialInput(type=type_value, password=password);
}

impl RegisterRequest.from_dict(data: any) -> RegisterRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    body: dict[str, any] = data;

    raw_identities = body.get('identities');
    if not isinstance(raw_identities, list) or len(raw_identities) == 0 {
        raise ValueError('identities must be a non-empty list');
    }
    identity_items: list[any] = raw_identities;
    if 'credential' not in body {
        raise ValueError('credential is required');
    }
    return RegisterRequest(
        identities=[IdentityInputModel.from_dict(item) for item in identity_items],
        credential=CredentialInput.from_dict(body.get('credential')),
        profile=validate_profile(body.get('profile')),
        challenge=body.get('challenge')
            if isinstance(body.get('challenge'), dict)
            else None
    );
}

impl LoginRequest.from_dict(data: any) -> LoginRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    body: dict[str, any] = data;
    if 'identity' not in body {
        raise ValueError('identity is required');
    }
    if 'credential' not in body {
        raise ValueError('credential is required');
    }
    return LoginRequest(
        identity=IdentityInputModel.from_dict(body.get('identity')),
        credential=CredentialInput.from_dict(body.get('credential'))
    );
}

impl FirebaseTokenRequest.from_dict(data: any) -> FirebaseTokenRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    return FirebaseTokenRequest(id_token=require_str(data, 'id_token'));
}

impl UpdatePasswordRequest.from_dict(data: any) -> UpdatePasswordRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    body: dict[str, any] = data;
    return UpdatePasswordRequest(
        current_password=require_str(body, 'current_password'),
        new_password=require_str(body, 'new_password'),
        username=str(body.get('username') or '')
    );
}

impl UpdateUsernameRequest.from_dict(data: any) -> UpdateUsernameRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    body: dict[str, any] = data;
    return UpdateUsernameRequest(
        new_username=require_str(body, 'new_username'),
        current_username=str(body.get('current_username') or '')
    );
}

impl AddIdentityRequest.from_dict(data: any) -> AddIdentityRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    body: dict[str, any] = data;
    if 'identity' not in body {
        raise ValueError('identity is required');
    }
    return AddIdentityRequest(
        identity=IdentityInputModel.from_dict(body.get('identity')),
        is_recovery=bool(body.get('is_recovery', False))
    );
}

impl VerifyIdentityRequest.from_dict(data: any) -> VerifyIdentityRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    return VerifyIdentityRequest(token=require_str(data, 'token'));
}

impl SendVerificationRequest.from_dict(data: any) -> SendVerificationRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    body: dict[str, any] = data;
    if 'identity' not in body {
        raise ValueError('identity is required');
    }
    return SendVerificationRequest(
        identity=IdentityInputModel.from_dict(body.get('identity'))
    );
}

impl ForgotPasswordRequest.from_dict(data: any) -> ForgotPasswordRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    body: dict[str, any] = data;
    if 'identity' not in body {
        raise ValueError('identity is required');
    }
    return ForgotPasswordRequest(
        identity=IdentityInputModel.from_dict(body.get('identity'))
    );
}

impl ResetPasswordRequest.from_dict(data: any) -> ResetPasswordRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    kw: dict[str, str] = {};
    comptime for f in fields(ResetPasswordRequest) {
        kw[f.name] = require_str(data, f.name);
    }
    return ResetPasswordRequest(**kw);
}

impl optional_str(data: dict[str, any], key: str) -> str {
    value = data.get(key);
    if value is None {
        return '';
    }
    if not isinstance(value, str) {
        raise ValueError(f"{key} must be a string");
    }
    return value;
}

impl EnrollFactorRequest.from_dict(data: any) -> EnrollFactorRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    return EnrollFactorRequest(
        password=require_str(data, 'password'),
        code=optional_str(data, 'code'),
        recovery_code=optional_str(data, 'recovery_code')
    );
}

impl VerifyFactorRequest.from_dict(data: any) -> VerifyFactorRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    return VerifyFactorRequest(
        factor_id=require_str(data, 'factor_id'), code=require_str(data, 'code')
    );
}

impl RemoveFactorRequest.from_dict(data: any) -> RemoveFactorRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    return RemoveFactorRequest(
        factor_id=require_str(data, 'factor_id'),
        code=optional_str(data, 'code'),
        recovery_code=optional_str(data, 'recovery_code')
    );
}

impl SecondFactorLoginRequest.from_dict(data: any) -> SecondFactorLoginRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    return SecondFactorLoginRequest(
        challenge_token=require_str(data, 'challenge_token'),
        code=optional_str(data, 'code'),
        recovery_code=optional_str(data, 'recovery_code')
    );
}

impl UpdateProfileRequest.from_dict(data: any) -> UpdateProfileRequest {
    if not isinstance(data, dict) {
        raise ValueError('request body must be an object');
    }
    body: dict[str, any] = data;

    raw_profile = body.get('profile');
    if raw_profile is None {
        raise ValueError('profile is required and must not be null');
    }
    validated = validate_profile(raw_profile);
    return UpdateProfileRequest(profile=validated or {});
}
