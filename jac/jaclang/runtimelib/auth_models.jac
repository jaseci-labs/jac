enum IdentityType { USERNAME = 'username' }


enum CredentialType { PASSWORD = 'password' }


obj IdentityInput {
    has type: str,
        value: str;

    static def from_dict(data: any) -> IdentityInput {
        if not isinstance(data, dict) {
            raise ValueError('identity must be an object');
        }
        type_value = data.get('type');
        value = data.get('value');
        if not isinstance(type_value, str) or not type_value {
            raise ValueError('identity.type is required');
        }
        if not isinstance(value, str) or not value {
            raise ValueError('identity.value is required');
        }
        return IdentityInput(type=type_value, value=value);
    }
}


obj CredentialInput {
    has type: str,
        password: str;

    static def from_dict(data: any) -> CredentialInput {
        if not isinstance(data, dict) {
            raise ValueError('credential must be an object');
        }
        type_value = data.get('type');
        password = data.get('password');
        if not isinstance(type_value, str) or not type_value {
            raise ValueError('credential.type is required');
        }
        if not isinstance(password, str) or not password {
            raise ValueError('credential.password is required');
        }
        return CredentialInput(type=type_value, password=password);
    }
}


obj LoginRequest {
    has identity: IdentityInput,
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
            identity=IdentityInput.from_dict(data.get('identity')),
            credential=CredentialInput.from_dict(data.get('credential'))
        );
    }
}


obj RegisterRequest {
    has identities: list[IdentityInput],
        credential: CredentialInput;

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
        identities = [IdentityInput.from_dict(item) for item in raw_identities];
        return RegisterRequest(
            identities=identities,
            credential=CredentialInput.from_dict(data.get('credential'))
        );
    }
}
