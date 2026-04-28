"""Auth request/response models for the identity-based auth system."""
import from typing { Annotated, Literal, Union }
import from pydantic { BaseModel, Field, EmailStr }
import from jac_scale.enums { CredentialType }


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
