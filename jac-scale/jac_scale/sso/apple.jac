"""Apple SSO Provider implementation for jac-scale.

This module implements the SSOProvider interface for Apple Sign In authentication.
"""

import from fastapi { Request, Response }
import from fastapi_sso.sso.apple { AppleSSO }
import from jac_scale.sso.provider { SSOProvider, SSOUserInfo }
import from jac_scale.enums { Platforms }

"""Apple Sign In SSO Provider.

This class wraps the fastapi_sso AppleSSO implementation to conform to
our SSOProvider interface, enabling consistent handling across all SSO vendors.
"""
obj AppleSSOProvider(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True,
        _apple_sso: (AppleSSO | None) = None;

    """Initialize the Apple SSO provider."""
    def postinit -> None {
        self._apple_sso = AppleSSO(
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.redirect_uri,
            allow_insecure_http=self.allow_insecure_http
        );
    }

    """Initiate Apple Sign In authentication flow.

    Returns:
        RedirectResponse to Apple's OAuth authorization page
    """
    async def initiate_auth -> Response {
        if not self._apple_sso {
            raise RuntimeError("AppleSSO not initialized");
        }

        with self._apple_sso {
            return await self._apple_sso.get_login_redirect();
        }
    }

    """Handle the OAuth callback from Apple.

    Args:
        request: The FastAPI request object containing OAuth callback data

    Returns:
        SSOUserInfo: Standardized user information from Apple

    Raises:
        Exception: If authentication fails or user info cannot be retrieved
    """
    async def handle_callback(request: Request) -> SSOUserInfo {
        if not self._apple_sso {
            raise RuntimeError("AppleSSO not initialized");
        }

        with self._apple_sso {
            user_info = await self._apple_sso.verify_and_process(request);
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
        str: 'apple'
    """
    def get_platform_name -> str {
        return Platforms.APPLE.value;
    }
}
