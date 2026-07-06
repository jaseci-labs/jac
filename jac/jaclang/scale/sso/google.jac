"""Google SSO Provider implementation for jac-scale.

This module implements the SSOProvider interface for Google OAuth authentication.
"""

import from fastapi_sso.sso.google { GoogleSSO }
import from jaclang.scale.sso.provider { FastAPISSOBase }

"""Google OAuth SSO Provider (fastapi_sso GoogleSSO behind FastAPISSOBase)."""
obj GoogleSSOProvider(FastAPISSOBase) {
    def _sso_class -> type {
        return GoogleSSO;
    }
}
