import from fastapi { Request, Response }
import from fastapi_sso.sso.google { GoogleSSO }
import from jac_scale.sso.provider { SSOProvider, SSOUserInfo }


obj GoogleSSOProvider(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True,
        _google_sso: (GoogleSSO | None) = None;

    def postinit {
        self._google_sso = GoogleSSO(
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.redirect_uri,
            allow_insecure_http=self.allow_insecure_http
        );
    }

    async def initiate_auth(state: str | None = None) -> Response {
        if not self._google_sso {
            raise RuntimeError("GoogleSSO not initialized");
        }

        with self._google_sso {
            return await self._google_sso.get_login_redirect(state=state);
        }
    }

    async def handle_callback(request: Request) -> SSOUserInfo {
        if not self._google_sso {
            raise RuntimeError("GoogleSSO not initialized");
        }

        with self._google_sso {
            user_info = await self._google_sso.verify_and_process(request);
            if user_info is None {
                raise RuntimeError("Google SSO verification returned no user info");
            }
            if user_info.email is None or user_info.id is None {
                raise RuntimeError("Google SSO user info is missing email or id");
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
