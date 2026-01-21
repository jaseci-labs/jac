cl import from .authLogic {
    validateCredentials,
    authView,
    shouldShowError
}

test empty_credentials_rejected {
    assert validateCredentials("", "") == "Please fill in all fields";
}

test short_username_rejected {
    assert validateCredentials("ab", "password123") != "";
}

test short_password_rejected {
    assert validateCredentials("alice", "123") != "";
}

test valid_credentials_accepted {
    assert validateCredentials("alice", "password123") == "";
}

test authView_returns_login_when_logged_out {
    assert authView(False) == "login";
}

test authView_returns_todos_when_logged_in {
    assert authView(True) == "todos";
}

test shouldShowError_works_correctly {
    assert shouldShowError("") == False;
    assert shouldShowError("error") == True;
}
