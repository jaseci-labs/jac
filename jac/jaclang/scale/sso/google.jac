obj GoogleSSOProvider(OAuth2CodeProvider) {
    def authorize_url -> str;
    def token_url -> str;
    def scope -> str;
    def connect_params -> dict[str, str];
    def revoke_url -> str;
    async def fetch_user(
        access_token: str, token_payload: dict[str, any]
    ) -> SSOUserInfo;
}
