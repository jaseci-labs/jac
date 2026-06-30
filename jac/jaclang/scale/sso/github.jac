"""GitHub SSO Provider implementation for jac-scale.

This module implements the SSOProvider interface for GitHub OAuth authentication.
"""

import from fastapi { Request, Response }
import from fastapi_sso.sso.github { GithubSSO }
import from jaclang.scale.sso.provider { SSOProvider, SSOUserInfo }

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
    def postinit {
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
    async def initiate_auth(state: str | None = None) -> Response {
        if not self._github_sso {
            raise RuntimeError("GithubSSO not initialized");
        }

        with self._github_sso {
            return await self._github_sso.get_login_redirect(state=state);
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
            if user_info is None {
                raise RuntimeError("Github SSO verification returned no user info");
            }
            if user_info.email is None or user_info.id is None {
                raise RuntimeError("Github SSO user info is missing email or id");
            }
            return SSOUserInfo(
                email=str(user_info.email),
                external_id=str(user_info.id),
                display_name=user_info.display_name,
                first_name=user_info.first_name,
                last_name=user_info.last_name,
                picture=user_info.picture
            );
        }
    }
}
