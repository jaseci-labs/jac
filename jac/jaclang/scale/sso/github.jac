obj GithubSSOProvider(OAuth2CodeProvider) {
    def authorize_url -> str;
    def token_url -> str;
    def needs_email -> bool;
    def scope -> str;
    async def _api_get(path: str, access_token: str) -> any;
    async def verified_primary_email(access_token: str) -> str;
    async def fetch_user(
        access_token: str, token_payload: dict[str, any]
    ) -> SSOUserInfo;
}
