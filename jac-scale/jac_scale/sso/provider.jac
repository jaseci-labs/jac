import from fastapi { Request, Response }

obj SSOUserInfo {
    has email: str,
        external_id: str,
        display_name: (str | None) = None,
        first_name: (str | None) = None,
        last_name: (str | None) = None,
        picture: (str | None) = None;

    def profile_fields -> dict[str, any] {
        fields: dict[str, any] = {};
        for key in ['display_name', 'first_name', 'last_name', 'picture'] {
            val = getattr(self, key, None);
            if val {
                fields[key] = val;
            }
        }
        return fields;
    }
}


obj SSOProvider {
    async def initiate_auth(state: str | None = None) -> Response;
    async def handle_callback(request: Request) -> SSOUserInfo;
}
