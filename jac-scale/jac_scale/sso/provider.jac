"""SSO Provider Abstraction for jac-scale.

This module defines the abstract interface for SSO providers, enabling
easy addition of new authentication vendors (Google, Microsoft, GitHub, SAML, etc.).
"""

import from typing { Any }
import from fastapi { Request, Response }

"""Standardized user information from SSO providers."""
obj SSOUserInfo {
    has email: str,
        external_id: str,
        display_name: (str | None) = None,
        first_name: (str | None) = None,
        last_name: (str | None) = None,
        picture: (str | None) = None;

    """Return populated optional profile fields as a flat dict, skipping
    any that are None. Caller decides namespacing (typically nested under
    profile.sso.<platform> using the URL platform)."""
    def profile_fields -> dict[str, Any] {
        fields: dict[str, Any] = {};
        for key in ['display_name', 'first_name', 'last_name', 'picture'] {
            val = getattr(self, key, None);
            if val {
                fields[key] = val;
            }
        }
        return fields;
    }
}

"""Abstract base class for SSO providers.

All SSO provider implementations must inherit from this class and implement
the required methods. This abstraction enables:

1. Consistent interface across all SSO vendors
2. Easy addition of new providers (just implement this interface)
3. Testability through mock implementations
4. Standardized user information format

Example:
    To add a new SSO provider (e.g., Microsoft):

    ```jac
    obj MicrosoftSSOProvider(SSOProvider) {
        async def initiate_auth -> Response;
        async def handle_callback(request: Request) -> SSOUserInfo;
    }
    ```
"""
obj SSOProvider {
    """Initialize SSO authentication flow.

    Returns:
        Response object (typically a redirect to the SSO provider's auth page)
    """
    async def initiate_auth -> Response;

    """Handle the OAuth callback from the SSO provider.

    Args:
        request: The FastAPI request object containing the OAuth callback data

    Returns:
        SSOUserInfo: Standardized user information from the provider

    Raises:
        Exception: If authentication fails or user info cannot be retrieved
    """
    async def handle_callback(request: Request) -> SSOUserInfo;
}
