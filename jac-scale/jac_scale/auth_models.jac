"""Auth request/response models for the identity-based auth system."""
import from pydantic { BaseModel, Field }
import from jac_scale.enums { IdentityType, CredentialType }


class IdentityInput(BaseModel) {
    has type: IdentityType = Field(..., description='Identity type: username, email'),
        value: str = Field(..., min_length=1, description='Identity value');
}

class CredentialInput(BaseModel) {
    has type: CredentialType = Field(..., description='Credential type: password'),
        password: str = Field(..., min_length=1, description='Password');
}

class RegisterRequest(BaseModel) {
    has identities: list[IdentityInput] = Field(
        ..., description='User identities (at least one required)'
    ),
        credential: CredentialInput = Field(..., description='User credential');
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
