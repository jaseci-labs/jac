import from jaclang.server.identity.config { auth_settings }
import from jaclang.server.serving.client { arequest }
import from jaclang.scale.sso.provider { OAuth2CodeProvider, SSOUserInfo }

obj GithubSSOProvider(OAuth2CodeProvider) {
    def authorize_url -> str {
        return 'https://github.com/login/oauth/authorize';
    }

    def token_url -> str {
        return 'https://github.com/login/oauth/access_token';
    }

    def needs_email -> bool {
        return auth_settings().identifiers.email == 'required';
    }

    def scope -> str {
        return 'user:email' if self.needs_email() else '';
    }

    async def _api_get(path: str, access_token: str) -> any {
        resp = await arequest(
            'GET',
            f"https://api.github.com{path}",
            headers={
                'Authorization': f"Bearer {access_token}",
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'jac-sso'
            }
        );
        if not resp.ok() {
            raise RuntimeError(f"GitHub API {path} failed: HTTP {resp.status_code}");
        }
        return resp.json();
    }

    async def verified_primary_email(access_token: str) -> str {
        try {
            listed = await self._api_get('/user/emails', access_token);
        } except RuntimeError {
            return '';
        }
        for item in (listed if isinstance(listed, list) else []) {
            if isinstance(item, dict)
                and item.get('primary')
                and item.get('verified') {
                return str(item.get('email') or '');
            }
        }
        return '';
    }

    async def fetch_user(
        access_token: str, token_payload: dict[str, any]
    ) -> SSOUserInfo {
        info = await self._api_get('/user', access_token);
        external_id = info.get('id');
        if external_id is None or not info.get('login') {
            raise RuntimeError('GitHub user info is missing login or id');
        }
        email = await self.verified_primary_email(access_token)
            if self.needs_email()
            else '';
        return SSOUserInfo(
            email=email,
            email_verified=bool(email),
            external_id=str(external_id),
            username=str(info['login']),
            display_name=info.get('name'),
            picture=info.get('avatar_url')
        );
    }
}
