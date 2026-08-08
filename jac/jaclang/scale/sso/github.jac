import from jaclang.runtimelib.serving.client { arequest }
import from jaclang.scale.sso.provider { OAuth2CodeProvider, SSOUserInfo }

obj GithubSSOProvider(OAuth2CodeProvider) {
    def authorize_url -> str {
        return 'https://github.com/login/oauth/authorize';
    }

    def token_url -> str {
        return 'https://github.com/login/oauth/access_token';
    }

    def scope -> str {
        return 'user:email';
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

    async def fetch_user(
        access_token: str, token_payload: dict[str, any]
    ) -> SSOUserInfo {
        info = await self._api_get('/user', access_token);
        email = info.get('email');
        if not email {
            emails = await self._api_get('/user/emails', access_token);
            if isinstance(emails, list) {
                for entry in emails {
                    if isinstance(entry, dict) and entry.get('primary') {
                        email = entry.get('email');
                        break;
                    }
                }
                if not email and emails {
                    first = emails[0];
                    email = first.get('email') if isinstance(first, dict) else None;
                }
            }
        }
        external_id = info.get('id');
        if not email or external_id is None {
            raise RuntimeError('GitHub user info is missing email or id');
        }
        return SSOUserInfo(
            email=str(email),
            external_id=str(external_id),
            display_name=info.get('name'),
            picture=info.get('avatar_url')
        );
    }
}
