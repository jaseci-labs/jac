import logging;
import json;
import secrets;
import re;
import from http.cookies { SimpleCookie }
import from jaclang.server.identity.auth_tokens { AuthTokenStore }
import from jaclang.server.serving.datatypes { RedirectResponse }
import from jaclang.scale.sso.provider { OAuth2CodeProvider }
import from jaclang.scale.sso.oauth_session {
    OAuthSession,
    challenge_of,
    complete_identity
}
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.serving.datatypes { Request, Response }
import from jaclang.server.transport { TransportResponse, Meta }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.config.firebase_env { firebase_project_id_env_hint }
import from jaclang.scale.shared.enums { Platforms, Operations }
import from jaclang.scale.shared.utils { is_safe_loopback_redirect }
import from jaclang.scale.sso.provider { SSOProvider, SSOUserInfo }

glob logger = logging.getLogger(__name__);


def sso_host -> str {
    return str(get_scale_config().get_sso_config()['host']);
}


def configured_platforms -> dict[str, dict[str, str]] {
    sso_config = get_scale_config().get_sso_config();
    platforms: dict[str, dict[str, str]] = {};
    for platform in Platforms {
        key = platform.value.lower();
        platform_config = sso_config.get(key, {});
        if platform.value == Platforms.FIREBASE.value {
            project_id = platform_config.get('project_id', '');
            if not project_id {
                continue;
            }
            platforms[platform.value] = {"project_id": project_id};
        } else {
            client_id = platform_config.get('client_id', '');
            client_secret = platform_config.get('client_secret', '');
            if not client_id or not client_secret {
                continue;
            }
            platforms[platform.value] = {
                "client_id": client_id,
                "client_secret": client_secret
            };
        }
    }
    return platforms;
}


obj SSOAuth {
    has users: UserManager,
        platforms: dict[str, dict[str, str]] = {};

    def postinit {
        if not self.platforms {
            self.platforms = configured_platforms();
        }
    }

    def get_sso(platform: str) -> SSOProvider | None;
    async def sso_initiate(
        platform: str, operation: str, client_callback: str | None = None
    ) -> Response | TransportResponse;

    async def sso_callback(request: Request, platform: str) -> TransportResponse;
    async def firebase_token_auth_with_id_token(id_token: str) -> TransportResponse;
    def _complete_sso_login(
        platform: str, user_info: SSOUserInfo
    ) -> TransportResponse;
}


impl SSOAuth.get_sso(platform: str) -> SSOProvider | None {
    if platform not in self.platforms {
        return None;
    }
    credentials = self.platforms[platform];
    if platform == Platforms.FIREBASE.value {
        import from jaclang.scale.sso.firebase { FirebaseSSOProvider }
        return FirebaseSSOProvider(project_id=credentials['project_id']);
    } elif platform == Platforms.GOOGLE.value {
        redirect_uri = f"{sso_host()}/sso/{platform}/callback";
        import from jaclang.scale.sso.google { GoogleSSOProvider }
        return GoogleSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    } elif platform == Platforms.APPLE.value {
        redirect_uri = f"{sso_host()}/sso/{platform}/callback";
        import from jaclang.scale.sso.apple { AppleSSOProvider }
        return AppleSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    } elif platform == Platforms.GITHUB.value {
        redirect_uri = f"{sso_host()}/sso/{platform}/callback";
        import from jaclang.scale.sso.github { GithubSSOProvider }
        return GithubSSOProvider(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    }
    return None;
}

impl SSOAuth.sso_initiate(
    platform: str, operation: str, client_callback: str | None = None
) -> Response | TransportResponse {
    if platform not in [p.value for p in Platforms] {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }

    if platform == Platforms.FIREBASE.value {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=(
                "Firebase Auth does not use redirect-based SSO flows. "
                "Send the Firebase ID token directly to "
                "POST /sso/firebase/token with a JSON body "
                '{"id_token": "<token>"}.'
            ),
            meta=Meta(extra={'http_status': 400})
        );
    }
    if platform not in self.platforms {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured. Please set SSO_{platform.upper()}_CLIENT_ID and SSO_{platform.upper()}_CLIENT_SECRET environment variables.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    if operation not in [o.value for o in Operations] {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=f"Invalid operation '{operation}'. Must be 'login' or 'register'",
            meta=Meta(extra={'http_status': 400})
        );
    }
    sso = self.get_sso(platform);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }

    if not isinstance(sso, OAuth2CodeProvider) {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED', message='Unsupported redirect provider'
        );
    }
    verifier = secrets.token_urlsafe(48);
    oauth_session = OAuthSession(users=self.users, provider=sso, platform=platform);
    started = oauth_session.begin(
        challenge_of(verifier),
        client_callback=(client_callback or "")
            if is_safe_loopback_redirect(client_callback)
            else ""
    );
    response = RedirectResponse(url=started.url, status_code=303);
    secure = sso.redirect_uri.startswith("https://");
    cookie = "jac_sso_"
        + started.state
        + "="
        + verifier
        + "; Path=/sso/; HttpOnly; Max-Age=600";
    cookie += "; SameSite=None; Secure" if secure else "; SameSite=Lax";
    response.headers.set("Set-Cookie", cookie);
    response.headers.set("Cache-Control", "no-store");
    return response;
}

impl SSOAuth.sso_callback(request: Request, platform: str) -> TransportResponse {
    if platform not in [p.value for p in Platforms] {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    if platform not in self.platforms {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    sso = self.get_sso(platform);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    if not isinstance(sso, OAuth2CodeProvider) {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED', message='Unsupported redirect provider'
        );
    }
    state = sso._callback_param(request, 'state') or '';
    if re.fullmatch(r"[A-Za-z0-9_-]{43}", state) is None {
        return TransportResponse.fail(
            code='INVALID_STATE',
            message='Invalid or missing sign-in state',
            meta=Meta(extra={'http_status': 401})
        );
    }
    cookies: any = SimpleCookie();
    try {
        cookies.load(request.headers.get('Cookie') or '');
    } except Exception {}
    cookie = cookies.get('jac_sso_' + state);
    verifier = str(cookie.value) if cookie else '';
    record = AuthTokenStore.instance().peek_token(state, 'oauth_session:' + platform);
    callback = str(json.loads(record['identity_value']).get('client_callback') or '')
        if record
        else '';
    oauth_session = OAuthSession(users=self.users, provider=sso, platform=platform);
    result = await oauth_session.finish(
        sso._callback_param(request, 'code') or '', state, verifier
    );
    if not result.ok {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=result.error,
            meta=Meta(extra={'http_status': 401})
        );
    }
    user_id = self.users.validate_jwt_token(result.token) or '';
    return TransportResponse.success(
        data={
            'message': 'Login successful',
            'token': result.token,
            'username': result.username,
            'user_id': user_id,
            'root_id': self.users.get_root_id(user_id) or '',
            'platform': platform
        },
        meta=Meta(extra={'http_status': 200, 'client_callback': callback})
    );
}

impl SSOAuth.firebase_token_auth_with_id_token(id_token: str) -> TransportResponse {
    platform = Platforms.FIREBASE.value;
    if platform not in self.platforms {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=(
                "Firebase Auth SSO is not configured. Set "
                "[scale.sso.firebase] project_id in jac.toml or "
                f"{firebase_project_id_env_hint()}"
            ),
            meta=Meta(extra={'http_status': 501})
        );
    }
    sso: any = self.get_sso(platform);
    if sso is None {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    try {
        user_info = await sso.handle_id_token(id_token);
    } except Exception as e {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=f"Firebase authentication failed: {str(e)}",
            meta=Meta(extra={'http_status': 401})
        );
    }

    return self._complete_sso_login(platform, user_info);
}

impl SSOAuth._complete_sso_login(
    platform: str, user_info: SSOUserInfo
) -> TransportResponse {
    result = complete_identity(self.users, user_info, platform);
    if not result.ok {
        return TransportResponse.fail(
            code='USER_CREATION_FAILED',
            message=result.error,
            meta=Meta(extra={'http_status': 400})
        );
    }
    user_id = self.users.validate_jwt_token(result.token) or '';
    return TransportResponse.success(
        data={
            'message': 'Login successful',
            'token': result.token,
            'username': result.username,
            'user_id': user_id,
            'root_id': self.users.get_root_id(user_id) or '',
            'platform': platform
        },
        meta=Meta(extra={'http_status': 200})
    );
}
