"""Apple SSO Provider implementation for jac-scale.

This module implements the SSOProvider interface for Apple Sign In authentication.
"""

import from fastapi_sso.sso.apple { AppleSSO }
import from jaclang.scale.sso.provider { FastAPISSOBase }

"""Apple Sign In SSO Provider (fastapi_sso AppleSSO behind FastAPISSOBase)."""
obj AppleSSOProvider(FastAPISSOBase) {
    def _sso_class -> type {
        return AppleSSO;
    }
}
