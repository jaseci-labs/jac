import from fastapi_sso.sso.google { GoogleSSO }
import from fastapi_sso.sso.base { SSOBase }
import from jaclang.scale.sso.provider { FastAPISSOBase }

obj GoogleSSOProvider(FastAPISSOBase) {
    def _make_sso -> SSOBase {
        return GoogleSSO(
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.redirect_uri,
            allow_insecure_http=self.allow_insecure_http
        );
    }
}
