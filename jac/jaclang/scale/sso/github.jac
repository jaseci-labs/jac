import from fastapi_sso.sso.github { GithubSSO }
import from fastapi_sso.sso.base { SSOBase }
import from jaclang.scale.sso.provider { FastAPISSOBase }

obj GithubSSOProvider(FastAPISSOBase) {
    def _make_sso -> SSOBase {
        return GithubSSO(
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.redirect_uri,
            allow_insecure_http=self.allow_insecure_http
        );
    }
}
