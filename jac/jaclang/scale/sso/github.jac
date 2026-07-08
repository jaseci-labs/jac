"""GitHub SSO Provider implementation for jac-scale.

This module implements the SSOProvider interface for GitHub OAuth authentication.
"""

import from fastapi_sso.sso.github { GithubSSO }
import from fastapi_sso.sso.base { SSOBase }
import from jaclang.scale.sso.provider { FastAPISSOBase }

"""GitHub OAuth SSO Provider (fastapi_sso GithubSSO behind FastAPISSOBase)."""
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
