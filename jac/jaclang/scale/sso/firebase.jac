import json;
import from fastapi { Request, Response }
import from jaclang.scale.sso.provider { SSOProvider, SSOUserInfo }
import from jaclang.scale.config.firebase_env { firebase_project_id_env_hint }
import from jaclang.scale._optdeps.optional_deps { require_optional }
import from jaclang.scale._optdeps.firebase_auth {
    HAS_FIREBASE_ADMIN,
    firebase_admin,
    auth,
    credentials
}

obj FirebaseSSOProvider(SSOProvider) {
    has project_id: str,
        _app: any = None;

    def postinit {
        if not self.project_id {
            raise ValueError(
                "Firebase SSO requires a project_id. "
                "Set [plugins.scale.sso.firebase] project_id in jac.toml "
                f"or {firebase_project_id_env_hint()}"
            );
        }
        if not HAS_FIREBASE_ADMIN {
            require_optional("firebase_admin", "storage.firebase");
        }
        fa: any = firebase_admin;
        cred_mod: any = credentials;

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

    async def initiate_auth(state: str | None = None) -> Response {
        raise RuntimeError(
            "Firebase Auth does not use OAuth redirect flows. "
            "Send the Firebase ID token directly to POST /sso/firebase/token "
            "with a JSON body {\"id_token\": \"<token>\"}."
        );
    }

    async def handle_id_token(id_token: str) -> SSOUserInfo {
        if not id_token {
            raise ValueError("Missing 'id_token'.");
        }

        import asyncio;
        import functools;

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
