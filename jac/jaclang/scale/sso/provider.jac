"""SSO Provider Abstraction for jac-scale.

This module defines the abstract interface for SSO providers, enabling
easy addition of new authentication vendors (Google, Microsoft, GitHub, SAML, etc.).
"""

import from fastapi { Request, Response }
import from fastapi_sso.sso.base { SSOBase }

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
    def profile_fields -> dict[str, any] {
        fields: dict[str, any] = {};
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

    Args:
        state: Optional opaque value round-tripped through the OAuth provider and
            returned on the callback. Used to carry a native/desktop client's own
            loopback redirect URL (RFC 8252) so the token is delivered to the
            origin that initiated the flow.

    Returns:
        Response object (typically a redirect to the SSO provider's auth page)
    """
    async def initiate_auth(state: str | None = None) -> Response;

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

"""Shared implementation for fastapi_sso-backed OAuth providers.

Subclasses supply the fastapi_sso SSO class and a display name; everything
else (constructor shape, redirect initiation, callback verification, and
SSOUserInfo mapping) is identical across vendors.
"""
obj FastAPISSOBase(SSOProvider) {
    has client_id: str,
        client_secret: str,
        redirect_uri: str,
        allow_insecure_http: bool = True,
        _sso: (SSOBase | None) = None;

    """Construct the fastapi_sso client this provider wraps."""
    def _make_sso -> SSOBase {
        raise NotImplementedError();
    }

    """Provider display name used in error messages."""
    def _label -> str {
        return type(self).__name__;
    }

    def postinit {
        self._sso = self._make_sso();
    }

    async def initiate_auth(state: str | None = None) -> Response {
        if not self._sso {
            raise RuntimeError(f"{self._label()} not initialized");
        }

        with self._sso {
            return await self._sso.get_login_redirect(state=state);
        }
    }

    async def handle_callback(request: Request) -> SSOUserInfo {
        if not self._sso {
            raise RuntimeError(f"{self._label()} not initialized");
        }

        with self._sso {
            user_info = await self._sso.verify_and_process(request);
            if user_info is None {
                raise RuntimeError(
                    f"{self._label()} verification returned no user info"
                );
            }
            if user_info.email is None or user_info.id is None {
                raise RuntimeError(f"{self._label()} user info is missing email or id");
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
