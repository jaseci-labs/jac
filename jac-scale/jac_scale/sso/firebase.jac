"""Firebase Auth SSO Provider implementation for jac-scale.

Unlike the OAuth-based providers (Google, Apple, GitHub), Firebase Auth does
not use a redirect flow. The client-side Firebase SDK authenticates the user
directly (email/password, phone, Google, Apple, anonymous, etc.) and obtains
an ID token (JWT). The client sends this ID token to our server endpoint
`POST /sso/firebase/token`, which verifies it via the Firebase Admin SDK and
extracts the user's identity.

This means a single Firebase SSO provider acts as a gateway for **all** Firebase
Auth sign-in methods — no per-provider OAuth configuration needed.

Anonymous Firebase Auth is not supported: Jac SSO requires an email claim on
the ID token. Anonymous users receive AUTHENTICATION_FAILED with a message
about the missing email claim.
"""

import json;
import from fastapi { Request, Response }
import from jac_scale.sso.provider { SSOProvider, SSOUserInfo }
import from jac_scale.firebase_env { firebase_project_id_env_hint }
import from jac_scale._optdeps.optional_deps { require_optional }
import from jac_scale._optdeps.firebase_auth {
    HAS_FIREBASE_ADMIN,
    firebase_admin,
    auth,
    credentials
}

"""Firebase Auth SSO Provider.

Verifies Firebase ID tokens using the Firebase Admin SDK and maps the
decoded claims to SSOUserInfo.

Configuration (jac.toml or env vars):

```toml
[plugins.scale.sso.firebase]
project_id = "my-firebase-project"
```

Or via environment variable:

```bash
export FIREBASE_PROJECT_ID="my-firebase-project"
# Subsystem override (optional):
# export FIREBASE_AUTH_PROJECT_ID="my-firebase-project"
```

Dependency: ``pip install jac-scale[firebase]``
"""
obj FirebaseSSOProvider(SSOProvider) {
    has project_id: str,
        _app: any = None;

    """Initialize the Firebase Admin SDK (lazy, idempotent)."""
    def postinit {
        if not self.project_id {
            raise ValueError(
                "Firebase SSO requires a project_id. "
                "Set [plugins.scale.sso.firebase] project_id in jac.toml "
                f"or {firebase_project_id_env_hint()}"
            );
        }
        if not HAS_FIREBASE_ADMIN {
            require_optional("firebase_admin", "firebase");
        }
        fa: any = firebase_admin;
        cred_mod: any = credentials;
        # Use a named app keyed by project_id so that multiple
        # FirebaseSSOProvider instances with different project IDs each get
        # their own isolated Firebase Admin app.  The default (unnamed) app is
        # intentionally avoided to prevent cross-project token verification.
        app_name = f"jac_sso_{self.project_id}";
        try {
            self._app = fa.get_app(name=app_name);
        } except ValueError {
            cred = cred_mod.ApplicationDefault();
            self._app = fa.initialize_app(
                cred, {'projectId': self.project_id}, name=app_name
            );
        }
    }

    """Not used for Firebase — clients send the ID token directly.

    Raises RuntimeError if called. Use ``handle_callback`` with a request
    that contains a JSON body ``{"id_token": "..."}`` instead.
    """
    async def initiate_auth(state: str | None = None) -> Response {
        raise RuntimeError(
            "Firebase Auth does not use OAuth redirect flows. "
            "Send the Firebase ID token directly to POST /sso/firebase/token "
            "with a JSON body {\"id_token\": \"<token>\"}."
        );
    }

    """Verify a raw Firebase ID token and map its claims to SSOUserInfo.

    This is the second entry point alongside ``handle_callback``: Firebase's
    direct-token flow hands us a JWT string (parsed from a typed request body
    by the /sso/firebase/token endpoint) rather than a redirect callback, so
    ``handle_callback`` delegates here after extracting the token. Verification
    lives in exactly one place.

    Returns:
        SSOUserInfo with email and Firebase UID as external_id, plus the
        display name and picture from the token claims when present.
    """
    async def handle_id_token(id_token: str) -> SSOUserInfo {
        if not id_token {
            raise ValueError("Missing 'id_token'.");
        }

        import asyncio;
        import functools;
        # verify_id_token checks signature, expiry, audience (project), and
        # issuer. check_revoked also rejects tokens for users who have been
        # disabled or signed out since the token was minted (one extra read).
        # Run in a thread pool to avoid blocking the async event loop.
        auth_mod: any = auth;
        decoded: any = await asyncio.to_thread(
            functools.partial(
                auth_mod.verify_id_token, id_token, app=self._app, check_revoked=True
            )
        );

        email = decoded.get("email");
        if not email {
            raise RuntimeError(
                "Firebase ID token does not contain an email claim. "
                "Anonymous Firebase Auth is not supported by Jac SSO — link an "
                "email/password, phone, or federated provider before signing in."
            );
        }

        uid = decoded.get("uid") or decoded.get("sub", "");
        display_name = decoded.get("name");
        picture = decoded.get("picture");

        # Firebase ID tokens carry only an unstructured `name` claim, not
        # separate given/family names — so we surface it as display_name and
        # leave first/last unset rather than guessing on whitespace.
        return SSOUserInfo(
            email=str(email),
            external_id=str(uid),
            display_name=str(display_name) if display_name else None,
            picture=str(picture) if picture else None
        );
    }

    async def handle_callback(request: Request) -> SSOUserInfo {
        body_bytes = await request.body();
        try {
            body = json.loads(body_bytes);
        } except ValueError {
            raise ValueError(
                "Request body must be valid JSON with an 'id_token' field."
            );
        }

        id_token_raw = body.get("id_token") if isinstance(body, dict) else None;
        if not id_token_raw {
            raise ValueError("Missing 'id_token' in request body.");
        }
        return await self.handle_id_token(str(id_token_raw));
    }
}
