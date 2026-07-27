import from fastapi { Request, Response }
import from fastapi_sso.sso.base { SSOBase }

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

obj FastAPISSOBase(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True,
        _sso: (SSOBase | None) = None;

    def _make_sso -> SSOBase {
        raise NotImplementedError();
    }

    def _label -> str {
        return type(self).__name__;
    }

    def postinit {
        self._sso = self._make_sso();
    }

    async def initiate_auth(state: str | None = None) -> Response {
        if not self._sso {
            raise RuntimeError(f"{self._label()} not initialized");
        }

        with self._sso {
            return await self._sso.get_login_redirect(state=state);
        }
    }

    async def handle_callback(request: Request) -> SSOUserInfo {
        if not self._sso {
            raise RuntimeError(f"{self._label()} not initialized");
        }

        with self._sso {
            user_info = await self._sso.verify_and_process(request);
            if user_info is None {
                raise RuntimeError(
                    f"{self._label()} verification returned no user info"
                );
            }
            if user_info.email is None or user_info.id is None {
                raise RuntimeError(f"{self._label()} user info is missing email or id");
            }
            return SSOUserInfo(
                email=str(user_info.email),
                external_id=str(user_info.id),
                display_name=user_info.display_name,
                first_name=user_info.first_name,
                last_name=user_info.last_name,
                picture=user_info.picture
            );
        }
    }
}
