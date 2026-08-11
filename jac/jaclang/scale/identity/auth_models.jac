import json;
import re;
import from jaclang.runtimelib.serving.model { ApiModel, require_str }
import from jaclang.scale.shared.enums { CredentialType }

glob PROFILE_MAX_KEYS: int = 20,
     PROFILE_MAX_KEY_LENGTH: int = 64,
     PROFILE_MAX_VALUE_LENGTH: int = 1024,
     PROFILE_MAX_JSON_BYTES: int = 8192,
     PROFILE_KEY_PATTERN = re.compile(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$'),
     PROFILE_RESERVED_KEYS: set[str] = {'sso'},
     EMAIL_PATTERN = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$'),
     IDENTITY_TYPES: set[str] = {'email', 'username'};


def validate_profile(profile: dict[str, any] | None) -> dict[str, any] | None {
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
        if not isinstance(key, str) or not PROFILE_KEY_PATTERN.match(key) {
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


obj IdentityInputModel(ApiModel) {
    has type: str,
        value: str;

    static def from_dict(data: any) -> IdentityInputModel {
        if not isinstance(data, dict) {
            raise ValueError('identity must be an object');
        }
        type_value = require_str(data, 'type', 'identity.type');
        if type_value not in IDENTITY_TYPES {
            raise ValueError("identity.type must be one of 'email' or 'username'");
        }
        value = require_str(data, 'value', 'identity.value');
        if type_value == 'email' and not EMAIL_PATTERN.match(value) {
            raise ValueError('identity.value is not a valid email address');
        }
        return IdentityInputModel(type=type_value, value=value);
    }
}

obj CredentialInput(ApiModel) {
    has type: str,
        password: str;

    static def from_dict(data: any) -> CredentialInput {
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
}

obj RegisterRequest(ApiModel) {
    has identities: list[IdentityInputModel],
        credential: CredentialInput,
        profile: (dict[str, any] | None) = None;

    static def from_dict(data: any) -> RegisterRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        raw_identities = data.get('identities');
        if not isinstance(raw_identities, list) or len(raw_identities) == 0 {
            raise ValueError('identities must be a non-empty list');
        }
        if 'credential' not in data {
            raise ValueError('credential is required');
        }
        return RegisterRequest(
            identities=[IdentityInputModel.from_dict(item) for item in raw_identities],
            credential=CredentialInput.from_dict(data.get('credential')),
            profile=validate_profile(data.get('profile'))
        );
    }
}

obj LoginRequest(ApiModel) {
    has identity: IdentityInputModel,
        credential: CredentialInput;

    static def from_dict(data: any) -> LoginRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        if 'identity' not in data {
            raise ValueError('identity is required');
        }
        if 'credential' not in data {
            raise ValueError('credential is required');
        }
        return LoginRequest(
            identity=IdentityInputModel.from_dict(data.get('identity')),
            credential=CredentialInput.from_dict(data.get('credential'))
        );
    }
}

obj FirebaseTokenRequest(ApiModel) {
    has id_token: str;

    static def from_dict(data: any) -> FirebaseTokenRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        return FirebaseTokenRequest(id_token=require_str(data, 'id_token'));
    }
}

obj UpdatePasswordRequest(ApiModel) {
    has current_password: str,
        new_password: str;

    static def from_dict(data: any) -> UpdatePasswordRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        return UpdatePasswordRequest(
            current_password=require_str(data, 'current_password'),
            new_password=require_str(data, 'new_password')
        );
    }
}

obj AddIdentityRequest(ApiModel) {
    has identity: IdentityInputModel,
        is_recovery: bool = False;

    static def from_dict(data: any) -> AddIdentityRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        if 'identity' not in data {
            raise ValueError('identity is required');
        }
        return AddIdentityRequest(
            identity=IdentityInputModel.from_dict(data.get('identity')),
            is_recovery=bool(data.get('is_recovery', False))
        );
    }
}

obj VerifyIdentityRequest(ApiModel) {
    has token: str;

    static def from_dict(data: any) -> VerifyIdentityRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        return VerifyIdentityRequest(token=require_str(data, 'token'));
    }
}

obj SendVerificationRequest(ApiModel) {
    has identity: IdentityInputModel;

    static def from_dict(data: any) -> SendVerificationRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        if 'identity' not in data {
            raise ValueError('identity is required');
        }
        return SendVerificationRequest(
            identity=IdentityInputModel.from_dict(data.get('identity'))
        );
    }
}

obj ForgotPasswordRequest(ApiModel) {
    has identity: IdentityInputModel;

    static def from_dict(data: any) -> ForgotPasswordRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        if 'identity' not in data {
            raise ValueError('identity is required');
        }
        return ForgotPasswordRequest(
            identity=IdentityInputModel.from_dict(data.get('identity'))
        );
    }
}

obj ResetPasswordRequest(ApiModel) {
    has token: str,
        new_password: str;

    static def from_dict(data: any) -> ResetPasswordRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        return ResetPasswordRequest(
            token=require_str(data, 'token'),
            new_password=require_str(data, 'new_password')
        );
    }
}

obj UpdateProfileRequest(ApiModel) {
    has profile: dict[str, any];

    static def from_dict(data: any) -> UpdateProfileRequest {
        if not isinstance(data, dict) {
            raise ValueError('request body must be an object');
        }
        raw_profile = data.get('profile');
        if raw_profile is None {
            raise ValueError('profile is required and must not be null');
        }
        validated = validate_profile(raw_profile);
        return UpdateProfileRequest(profile=validated or {});
    }
}

obj UpdateProfileResponse(ApiModel) {
    has message: str,
        profile: dict[str, any] = {};
}

obj MeIdentity(ApiModel) {
    has type: str,
        verified: bool = False,
        is_recovery: bool = False,
        value: (str | None) = None,
        provider: (str | None) = None;
}

obj MeResponse(ApiModel) {
    has user_id: str,
        role: str = 'user',
        status: str = 'active',
        identities: list[MeIdentity] = [],
        profile: dict[str, any] = {},
        created_at: (str | None) = None,
        updated_at: (str | None) = None;
}
