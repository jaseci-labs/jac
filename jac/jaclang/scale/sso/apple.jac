import from fastapi_sso.sso.apple { AppleSSO }
import from fastapi_sso.sso.base { SSOBase }
import from jaclang.scale.sso.provider { FastAPISSOBase }

obj AppleSSOProvider(FastAPISSOBase) {
    def _make_sso -> SSOBase {
        return AppleSSO(
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.redirect_uri,
            allow_insecure_http=self.allow_insecure_http
        );
    }
}
