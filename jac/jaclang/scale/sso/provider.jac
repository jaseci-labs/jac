import json;
import from base64 { urlsafe_b64decode }
import from urllib.parse { urlencode }

obj SSOUserInfo {
    has email: str,
        external_id: str,
        email_verified: bool = False,
        username: str = '',
        display_name: (str | None) = None,
        first_name: (str | None) = None,
        last_name: (str | None) = None,
        picture: (str | None) = None;

    def verified_email -> str;
    def profile_fields -> dict[str, any];
}

obj SSOProvider {
    async def initiate_auth(state: str | None = None) -> Response abst;
    async def handle_callback(request: Request) -> SSOUserInfo abst;
}

def decode_jwt_payload_unverified(token: str) -> dict[str, any];

obj OAuth2CodeProvider(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True;

    def _label -> str;
    def authorize_url -> str;
    def token_url -> str;
    def scope -> str;
    def extra_authorize_params -> dict[str, str];
    async def fetch_user(
        access_token: str, token_payload: dict[str, any]
    ) -> SSOUserInfo;

    async def initiate_auth(state: str | None = None) -> Response;
    async def _exchange_code(code: str, code_verifier: str = '') -> dict[str, any];
    static def _callback_param(request: Request, name: str) -> (str | None);
    async def handle_callback(request: Request) -> SSOUserInfo;
}
