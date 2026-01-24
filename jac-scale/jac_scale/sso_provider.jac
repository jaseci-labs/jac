"""SSO Provider Abstraction for jac-scale.

This module defines the abstract interface for SSO providers, enabling
easy addition of new authentication vendors (Google, Microsoft, GitHub, SAML, etc.).
"""

import from typing { Any }
import from fastapi { Request, Response }
import from dataclasses { dataclass }

"""Standardized user information from SSO providers."""
@dataclass
class SSOUserInfo {
    has email: str,
        external_id: str,
        platform: str,
        display_name: (str | None) = None;
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
        # Implement the three required methods
        async def initiate_auth(operation: str) -> Response;
        async def handle_callback(request: Request) -> SSOUserInfo;
        def get_platform_name() -> str;
    }
    ```
"""
obj SSOProvider {
    """Initialize SSO authentication flow.

    Args:
        operation: The operation type ('login' or 'register')

    Returns:
        Response object (typically a redirect to the SSO provider's auth page)
    """
    async def initiate_auth(operation: str) -> Response;

    """Handle the OAuth callback from the SSO provider.

    Args:
        request: The FastAPI request object containing the OAuth callback data

    Returns:
        SSOUserInfo: Standardized user information from the provider

    Raises:
        Exception: If authentication fails or user info cannot be retrieved
    """
    async def handle_callback(request: Request) -> SSOUserInfo;

    """Get the platform identifier for this provider.

    Returns:
        str: Platform name (e.g., 'google', 'microsoft', 'github')
    """
    def get_platform_name -> str;
}
