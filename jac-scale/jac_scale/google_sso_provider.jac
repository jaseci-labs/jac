"""Google SSO Provider implementation for jac-scale.

This module implements the SSOProvider interface for Google OAuth authentication.
"""

import from fastapi { Request, Response }
import from fastapi_sso.sso.google { GoogleSSO }
import from jac_scale.sso_provider { SSOProvider, SSOUserInfo }

"""Google OAuth SSO Provider.

This class wraps the fastapi_sso GoogleSSO implementation to conform to
our SSOProvider interface, enabling consistent handling across all SSO vendors.
"""
obj GoogleSSOProvider(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True,
        _google_sso: (GoogleSSO | None) = None;

    """Initialize the Google SSO provider."""
    def postinit -> None {
        self._google_sso = GoogleSSO(
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.redirect_uri,
            allow_insecure_http=self.allow_insecure_http
        );
    }

    """Initiate Google OAuth authentication flow.

    Args:
        operation: The operation type ('login' or 'register')

    Returns:
        RedirectResponse to Google's OAuth authorization page
    """
    async def initiate_auth(operation: str) -> Response {
        if not self._google_sso {
            raise RuntimeError("GoogleSSO not initialized") ;
        }

        with self._google_sso {
            return await self._google_sso.get_login_redirect();
        }
    }

    """Handle the OAuth callback from Google.

    Args:
        request: The FastAPI request object containing OAuth callback data

    Returns:
        SSOUserInfo: Standardized user information from Google

    Raises:
        Exception: If authentication fails or user info cannot be retrieved
    """
    async def handle_callback(request: Request) -> SSOUserInfo {
        if not self._google_sso {
            raise RuntimeError("GoogleSSO not initialized") ;
        }

        with self._google_sso {
            user_info = await self._google_sso.verify_and_process(request);
            return SSOUserInfo(
                email=user_info.email,
                external_id=user_info.id,
                platform=self.get_platform_name(),
                display_name=user_info?.display_name
            );
        }
    }

    """Get the platform identifier.

    Returns:
        str: 'google'
    """
    def get_platform_name -> str {
        return "google";
    }
}
