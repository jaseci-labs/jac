"""Auth request/response models for the identity-based auth system."""
import json;
import re;
import from typing { Annotated, Any, Literal, Union }
import from pydantic { BaseModel, Field, EmailStr, AfterValidator }
import from jac_scale.enums { CredentialType }

glob PROFILE_MAX_KEYS: int = 20,
     PROFILE_MAX_KEY_LENGTH: int = 64,
     PROFILE_MAX_VALUE_LENGTH: int = 1024,
     PROFILE_MAX_JSON_BYTES: int = 8192,
     PROFILE_KEY_PATTERN = re.compile(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$'),
     PROFILE_RESERVED_KEYS: set[str] = {'sso'};


"""Validate a profile dict. Returns the dict unchanged or raises ValueError.
Reused by /user/register and PATCH /user/me."""
def validate_profile(profile: dict[str, Any] | None) -> dict[str, Any] | None {
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
        # bool is a subclass of int in Python, so this allows str/int/float/bool only.
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

glob ValidatedProfile = Annotated[
         dict[str, Any] | None,
         AfterValidator(validate_profile)
     ],
     RequiredValidatedProfile = Annotated[
         dict[str, Any],
         AfterValidator(validate_profile)
     ];


class EmailIdentityInput(BaseModel) {
    has type: Literal['email'] = Field('email', description='Identity type: email'),
        value: EmailStr = Field(..., description='Email address');
}

class UsernameIdentityInput(BaseModel) {
    has type: Literal['username'] = Field(
        'username', description='Identity type: username'
    ),
        value: str = Field(..., min_length=1, description='Username');
}

glob IdentityInput = Annotated[
         Union[EmailIdentityInput, UsernameIdentityInput],
         Field(..., discriminator='type')
     ];

class CredentialInput(BaseModel) {
    has type: CredentialType = Field(..., description='Credential type: password'),
        password: str = Field(..., min_length=1, description='Password');
}

class RegisterRequest(BaseModel) {
    has identities: list[IdentityInput] = Field(
        ..., description='User identities (at least one required)'
    ),
        credential: CredentialInput = Field(..., description='User credential'),
        profile: ValidatedProfile = Field(
            default=None,
            description='Optional profile fields (firstname, lastname, address, postcode, etc.). Values must be string/number/boolean.'
        );
}

class LoginRequest(BaseModel) {
    has identity: IdentityInput = Field(
        ..., description='User identity (username or email)'
    ),
        credential: CredentialInput = Field(..., description='User credential');
}

class UpdatePasswordRequest(BaseModel) {
    has current_password: str = Field(
        ..., min_length=1, description='Current password'
    ),
        new_password: str = Field(..., min_length=1, description='New password');
}

class UpdateProfileRequest(BaseModel) {
    has profile: RequiredValidatedProfile = Field(
        ...,
        description='Profile fields to merge into the existing profile. Reserved keys (e.g. sso) are rejected. Must not be null.'
    );
}

class UpdateProfileResponse(BaseModel) {
    has message: str = Field(..., description='Result message'),
        profile: dict[str, Any] = Field(
            {}, description='The user\'s profile after the merge'
        );
}

class MeIdentity(BaseModel) {
    has type: str = Field(..., description='Identity type (email, username, sso)'),
        verified: bool = Field(False, description='Whether the identity is verified'),
        is_recovery: bool = Field(
            False, description='Whether the identity is a recovery identity'
        ),
        value: str | None = Field(
            None, description='Identity value (email/username); omitted for sso'
        ),
        provider: str | None = Field(
            None, description='SSO provider (only set when type=sso)'
        );
}

class MeResponse(BaseModel) {
    has user_id: str = Field(..., description='User ID'),
        role: str = Field('user', description='User role'),
        status: str = Field('active', description='User status'),
        identities: list[MeIdentity] = Field([], description='User identities'),
        profile: dict[str, Any] = Field({}, description='User profile fields'),
        created_at: str | None = Field(None, description='Creation timestamp'),
        updated_at: str | None = Field(None, description='Last update timestamp');
}
