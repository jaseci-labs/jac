import json;
import from base64 { urlsafe_b64decode }
import from urllib.parse { urlencode }
import from jaclang.server.serving.client { arequest }
import from jaclang.server.serving.datatypes { RedirectResponse, Request, Response }

obj SSOUserInfo {
    has email: str,
        external_id: str,
        username: str = '',
        display_name: (str | None) = None,
        first_name: (str | None) = None,
        last_name: (str | None) = None,
        picture: (str | None) = None;

    def profile_fields -> dict[str, any] {
        fields: dict[str, any] = {};
        for key in ['display_name', 'first_name', 'last_name', 'picture', 'username'] {
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

def decode_jwt_payload_unverified(token: str) -> dict[str, any] {
    parts = token.split('.');
    if len(parts) != 3 {
        raise RuntimeError('malformed id_token');
    }
    body_part = parts[1];
    padding = '=' * (-len(body_part) % 4);
    try {
        return json.loads(urlsafe_b64decode(body_part + padding));
    } except Exception {
        raise RuntimeError('undecodable id_token payload');
    }
}

obj OAuth2CodeProvider(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True;

    def _label -> str {
        return type(self).__name__;
    }

    def authorize_url -> str {
        raise NotImplementedError();
    }

    def token_url -> str {
        raise NotImplementedError();
    }

    def scope -> str {
        return '';
    }

    def extra_authorize_params -> dict[str, str] {
        return {};
    }

    async def fetch_user(
        access_token: str, token_payload: dict[str, any]
    ) -> SSOUserInfo {
        raise NotImplementedError();
    }

    async def initiate_auth(state: str | None = None) -> Response {
        params: dict[str, str] = {
            'client_id': self.client_id,
            'redirect_uri': self.redirect_uri,
            'response_type': 'code'
        };
        scope_value = self.scope();
        if scope_value {
            params['scope'] = scope_value;
        }
        if state {
            params['state'] = state;
        }
        params.update(self.extra_authorize_params());
        return RedirectResponse(
            url=f"{self.authorize_url()}?{urlencode(params)}", status_code=303
        );
    }

    async def _exchange_code(code: str, code_verifier: str = '') -> dict[str, any] {
        fields = {
            'grant_type': 'authorization_code',
            'code': code,
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'redirect_uri': self.redirect_uri
        };
        if code_verifier {
            fields['code_verifier'] = code_verifier;
        }
        form = urlencode(fields);
        resp = await arequest(
            'POST',
            self.token_url(),
            headers={
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json'
            },
            data=form
        );
        if not resp.ok() {
            raise RuntimeError(
                f"{self._label()} token exchange failed: " f"HTTP {resp.status_code}"
            );
        }
        payload = resp.json();
        if not isinstance(payload, dict) {
            raise RuntimeError(f"{self._label()} token endpoint returned a non-object");
        }
        return payload;
    }

    static def _callback_param(request: Request, name: str) -> (str | None) {
        value = request.query_params.get(name);
        if value is not None {
            return value;
        }
        values = request.form_fields.get(name, []);
        return values[0] if values else None;
    }

    async def handle_callback(request: Request) -> SSOUserInfo {
        error = self._callback_param(request, 'error');
        if error {
            raise RuntimeError(f"{self._label()} returned error: {error}");
        }
        code = self._callback_param(request, 'code');
        if not code {
            raise RuntimeError(
                f"{self._label()} callback is missing the authorization code"
            );
        }
        payload = await self._exchange_code(code);
        access_token = str(payload.get('access_token') or '');
        return await self.fetch_user(access_token, payload);
    }
}
