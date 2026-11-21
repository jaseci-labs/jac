impl set_current_auth(token: str | None) -> any {
    return _auth_token.set(token or "");
}

impl reset_current_auth(token_obj: any) {
    _auth_token.reset(token_obj);
}

impl get_current_auth -> str {
    return _auth_token.get("");
}
