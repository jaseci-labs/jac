import json;

obj FirebaseSSOProvider(SSOProvider) {
    has project_id: str,
        _app: any = None;

    def postinit;
    async def initiate_auth(state: str | None = None) -> Response;
    async def handle_id_token(id_token: str) -> SSOUserInfo;
    async def handle_callback(request: Request) -> SSOUserInfo;
}
