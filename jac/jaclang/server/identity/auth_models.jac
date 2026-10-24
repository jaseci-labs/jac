import json;
import re;

enum CredentialType { PASSWORD = 'password', }

glob PROFILE_MAX_KEYS: int = 20,
     PROFILE_MAX_KEY_LENGTH: int = 64,
     PROFILE_MAX_VALUE_LENGTH: int = 1024,
     PROFILE_MAX_JSON_BYTES: int = 8192,
     PROFILE_KEY_PATTERN = re.compile(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$'),
     PROFILE_RESERVED_KEYS: set[str] = {'sso'},
     EMAIL_PATTERN = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$'),
     IDENTITY_TYPES: set[str] = {'email', 'username'};


def validate_profile(profile: dict[str, any] | None) -> dict[str, any] | None;


obj IdentityInputModel(ApiModel) {
    has type: str,
        value: str;

    static def from_dict(data: any) -> IdentityInputModel;
}

obj CredentialInput(ApiModel) {
    has type: str,
        password: str;

    static def from_dict(data: any) -> CredentialInput;
}

obj RegisterRequest(ApiModel) {
    has identities: list[IdentityInputModel],
        credential: CredentialInput,
        profile: (dict[str, any] | None) = None,
        challenge: (dict[str, any] | None) = None;

    static def from_dict(data: any) -> RegisterRequest;
}

obj LoginRequest(ApiModel) {
    has identity: IdentityInputModel,
        credential: CredentialInput;

    static def from_dict(data: any) -> LoginRequest;
}

obj FirebaseTokenRequest(ApiModel) {
    has id_token: str;

    static def from_dict(data: any) -> FirebaseTokenRequest;
}

obj UpdatePasswordRequest(ApiModel) {
    has current_password: str,
        new_password: str,
        username: str = '';

    static def from_dict(data: any) -> UpdatePasswordRequest;
}

obj UpdateUsernameRequest(ApiModel) {
    has new_username: str,
        current_username: str = '';

    static def from_dict(data: any) -> UpdateUsernameRequest;
}

obj AddIdentityRequest(ApiModel) {
    has identity: IdentityInputModel,
        is_recovery: bool = False;

    static def from_dict(data: any) -> AddIdentityRequest;
}

obj VerifyIdentityRequest(ApiModel) {
    has token: str;

    static def from_dict(data: any) -> VerifyIdentityRequest;
}

obj SendVerificationRequest(ApiModel) {
    has identity: IdentityInputModel;

    static def from_dict(data: any) -> SendVerificationRequest;
}

obj ForgotPasswordRequest(ApiModel) {
    has identity: IdentityInputModel;

    static def from_dict(data: any) -> ForgotPasswordRequest;
}

obj ResetPasswordRequest(ApiModel) {
    has token: str,
        new_password: str;

    static def from_dict(data: any) -> ResetPasswordRequest;
}

def optional_str(data: dict[str, any], key: str) -> str;

obj EnrollFactorRequest(ApiModel) {
    has password: str,
        code: str = '',
        recovery_code: str = '';

    static def from_dict(data: any) -> EnrollFactorRequest;
}

obj VerifyFactorRequest(ApiModel) {
    has factor_id: str,
        code: str;

    static def from_dict(data: any) -> VerifyFactorRequest;
}

obj RemoveFactorRequest(ApiModel) {
    has factor_id: str,
        code: str = '',
        recovery_code: str = '';

    static def from_dict(data: any) -> RemoveFactorRequest;
}

obj SecondFactorLoginRequest(ApiModel) {
    has challenge_token: str,
        code: str = '',
        recovery_code: str = '';

    static def from_dict(data: any) -> SecondFactorLoginRequest;
}

obj UpdateProfileRequest(ApiModel) {
    has profile: dict[str, any];

    static def from_dict(data: any) -> UpdateProfileRequest;
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
