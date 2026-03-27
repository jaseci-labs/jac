"""GitHub SSO Provider implementation for jac-scale.

This module implements the SSOProvider interface for GitHub OAuth authentication.
"""

import from fastapi { Request, Response }
import from fastapi_sso.sso.github { GithubSSO }
import from jac_scale.sso.provider { SSOProvider, SSOUserInfo }
import from jac_scale.enums { Platforms }

"""GitHub OAuth SSO Provider.

This class wraps the fastapi_sso GithubSSO implementation to conform to
our SSOProvider interface, enabling consistent handling across all SSO vendors.
"""
obj GithubSSOProvider(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True,
        _github_sso: (GithubSSO | None) = None;

    """Initialize the GitHub SSO provider."""
    def postinit -> None {
        self._github_sso = GithubSSO(
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.redirect_uri,
            allow_insecure_http=self.allow_insecure_http
        );
    }

    """Initiate GitHub OAuth authentication flow.

    Returns:
        RedirectResponse to GitHub's OAuth authorization page
    """
    async def initiate_auth -> Response {
        if not self._github_sso {
            raise RuntimeError("GithubSSO not initialized");
        }

        with self._github_sso {
            return await self._github_sso.get_login_redirect();
        }
    }

    """Handle the OAuth callback from GitHub.

    Args:
        request: The FastAPI request object containing OAuth callback data

    Returns:
        SSOUserInfo: Standardized user information from GitHub

    Raises:
        Exception: If authentication fails or user info cannot be retrieved
    """
    async def handle_callback(request: Request) -> SSOUserInfo {
        if not self._github_sso {
            raise RuntimeError("GithubSSO not initialized");
        }

        with self._github_sso {
            user_info = await self._github_sso.verify_and_process(request);
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
        str: 'github'
    """
    def get_platform_name -> str {
        return Platforms.GITHUB.value;
    }
}
