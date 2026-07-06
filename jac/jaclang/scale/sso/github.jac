"""GitHub SSO Provider implementation for jac-scale.

This module implements the SSOProvider interface for GitHub OAuth authentication.
"""

import from fastapi_sso.sso.github { GithubSSO }
import from jaclang.scale.sso.provider { FastAPISSOBase }

"""GitHub OAuth SSO Provider (fastapi_sso GithubSSO behind FastAPISSOBase)."""
obj GithubSSOProvider(FastAPISSOBase) {
    def _sso_class -> type {
        return GithubSSO;
    }
}
