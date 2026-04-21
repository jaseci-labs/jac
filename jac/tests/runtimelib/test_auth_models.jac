"""Unit tests for jaclang.runtimelib.auth_models from_dict validators."""

import from jaclang.runtimelib.auth_models {
    IdentityInput,
    CredentialInput,
    LoginRequest,
    RegisterRequest
}


test "LoginRequest accepts a valid payload" {
    req = LoginRequest.from_dict({
        "identity": {"type": "username", "value": "alice"},
        "credential": {"type": "password", "password": "s3cret"}
    });
    assert req.identity.type == "username";
    assert req.identity.value == "alice";
    assert req.credential.type == "password";
    assert req.credential.password == "s3cret";
}

test "RegisterRequest accepts a valid payload" {
    req = RegisterRequest.from_dict({
        "identities": [{"type": "username", "value": "alice"}],
        "credential": {"type": "password", "password": "s3cret"}
    });
    assert len(req.identities) == 1;
    assert req.identities[0].value == "alice";
    assert req.credential.password == "s3cret";
}

test "LoginRequest rejects missing identity" {
    raised = False;
    try {
        LoginRequest.from_dict({
            "credential": {"type": "password", "password": "s3cret"}
        });
    } except ValueError as e {
        assert "identity is required" in str(e);
        raised = True;
    }
    assert raised;
}

test "LoginRequest rejects missing credential" {
    raised = False;
    try {
        LoginRequest.from_dict({
            "identity": {"type": "username", "value": "alice"}
        });
    } except ValueError as e {
        assert "credential is required" in str(e);
        raised = True;
    }
    assert raised;
}

test "RegisterRequest rejects empty identities list" {
    raised = False;
    try {
        RegisterRequest.from_dict({
            "identities": [],
            "credential": {"type": "password", "password": "s3cret"}
        });
    } except ValueError as e {
        assert "identities must be a non-empty list" in str(e);
        raised = True;
    }
    assert raised;
}

test "IdentityInput rejects empty value" {
    raised = False;
    try {
        IdentityInput.from_dict({"type": "username", "value": ""});
    } except ValueError as e {
        assert "identity.value is required" in str(e);
        raised = True;
    }
    assert raised;
}

test "CredentialInput rejects non-string password" {
    raised = False;
    try {
        CredentialInput.from_dict({"type": "password", "password": 123});
    } except ValueError as e {
        assert "credential.password is required" in str(e);
        raised = True;
    }
    assert raised;
}

test "LoginRequest rejects non-dict body" {
    raised = False;
    try {
        LoginRequest.from_dict("not a dict");
    } except ValueError as e {
        assert "request body must be an object" in str(e);
        raised = True;
    }
    assert raised;
}
