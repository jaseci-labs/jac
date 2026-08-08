import from jaclang.runtimelib.serving.client { arequest }
import from jaclang.scale.sso.provider { OAuth2CodeProvider, SSOUserInfo }

obj GoogleSSOProvider(OAuth2CodeProvider) {
    def authorize_url -> str {
        return 'https://accounts.google.com/o/oauth2/v2/auth';
    }

    def token_url -> str {
        return 'https://oauth2.googleapis.com/token';
    }

    def scope -> str {
        return 'openid email profile';
    }

    async def fetch_user(
        access_token: str, token_payload: dict[str, any]
    ) -> SSOUserInfo {
        resp = await arequest(
            'GET',
            'https://www.googleapis.com/oauth2/v3/userinfo',
            headers={'Authorization': f"Bearer {access_token}"}
        );
        if not resp.ok() {
            raise RuntimeError(
                f"Google userinfo request failed: HTTP {resp.status_code}"
            );
        }
        info = resp.json();
        email = info.get('email');
        external_id = info.get('sub');
        if not email or not external_id {
            raise RuntimeError('Google user info is missing email or id');
        }
        return SSOUserInfo(
            email=str(email),
            external_id=str(external_id),
            display_name=info.get('name'),
            first_name=info.get('given_name'),
            last_name=info.get('family_name'),
            picture=info.get('picture')
        );
    }
}
