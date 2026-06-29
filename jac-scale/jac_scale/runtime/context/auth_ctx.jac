import from contextvars { ContextVar }

glob _auth_token: ContextVar[str] = ContextVar("_sv_auth_token", default="");

def set_current_auth(token: str | None) -> any {
    return _auth_token.set(token or "");
}

def reset_current_auth(token_obj: any) {
    _auth_token.reset(token_obj);
}

def get_current_auth -> str {
    return _auth_token.get("");
}
