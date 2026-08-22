import from jaclang.scale.sso.provider {
    OAuth2CodeProvider,
    SSOUserInfo,
    decode_jwt_payload_unverified
}

obj AppleSSOProvider(OAuth2CodeProvider) {
    def authorize_url -> str {
        return 'https://appleid.apple.com/auth/authorize';
    }

    def token_url -> str {
        return 'https://appleid.apple.com/auth/token';
    }

    def scope -> str {
        return 'name email';
    }

    def extra_authorize_params -> dict[str, str] {
        return {'response_mode': 'form_post'};
    }

    async def fetch_user(
        access_token: str, token_payload: dict[str, any]
    ) -> SSOUserInfo {
        id_token = str(token_payload.get('id_token') or '');
        if not id_token {
            raise RuntimeError('Apple token response is missing id_token');
        }
        claims = decode_jwt_payload_unverified(id_token);
        email = claims.get('email');
        external_id = claims.get('sub');
        if not email or not external_id {
            raise RuntimeError('Apple id_token is missing email or sub');
        }
        return SSOUserInfo(email=str(email), external_id=str(external_id));
    }
}
