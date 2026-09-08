import json;
import from urllib.parse { quote }
import from jaclang.server.identity.auth_models { FirebaseTokenRequest }
import from jaclang.server.middleware { require_user }
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.server.serving.datatypes { RedirectResponse, Request, Response }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.server.transport { TransportResponse }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.shared.utils { is_safe_loopback_redirect }
import from jaclang.scale.sso.sso_auth { SSOAuth }
import from jaclang.scale.sso.provider { OAuth2CodeProvider }
import from jaclang.scale.sso.oauth_session { OAuthSession }
import from jaclang.runtime.object_model { asdict }
import from jaclang.scale.webhook.webhook { ApiKeyManager }


def resolve_sso_client_redirect(requested: (str | None), configured: str) -> str {
    if requested and is_safe_loopback_redirect(requested) {
        return requested;
    }
    return configured;
}


obj SSOExtension(ServerExtension) {
    has sso: (SSOAuth | None) = None;

    def register(server: JacAPIServer) {
        sso = SSOAuth(users=server.user_manager);
        self.sso = sso;
        platform_param = APIParameter(
            name='platform',
            data_type='string',
            required=True,
            description='SSO platform: google, apple, github',
            kind=ParameterType.PATH
        );

        async def sso_initiate(
            platform: str, operation: str, client_callback: (str | None) = None
        ) -> (Response | TransportResponse) {
            return await sso.sso_initiate(platform, operation, client_callback);
        }
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/sso/{platform}/{operation}',
                callback=sso_initiate,
                parameters=[
                    platform_param,
                    APIParameter(
                        name='operation',
                        data_type='string',
                        required=True,
                        description='Operation: "login" or "register"',
                        kind=ParameterType.PATH
                    ),
                    APIParameter(
                        name='client_callback',
                        data_type='string',
                        required=False,
                        description='Optional loopback URL for native clients; the token is redirected there after auth. Ignored unless it is a loopback address.',
                        kind=ParameterType.QUERY
                    )
                ],
                tags=['SSO APIs'],
                summary='Initiate SSO authentication',
                description='Redirects to the SSO provider for authentication.'
            )
        );

        def configured_session(platform: str) -> OAuthSession | None {
            provider = sso.get_sso(platform);
            if not isinstance(provider, OAuth2CodeProvider) {
                return None;
            }
            return OAuthSession(
                users=server.user_manager, provider=provider, platform=platform
            );
        }
        async def oauth_begin(
            request: Request, platform: str, challenge: str, mode: str = "web"
        ) -> TransportResponse {
            session = configured_session(platform);
            if session is None {
                return TransportResponse.fail(
                    code="SSO_NOT_CONFIGURED", message="SSO provider is not configured"
                );
            }
            link_user = "";
            if request.headers.get("Authorization") {
                (user_id, error) = require_user(request);
                if error is not None {
                    return error;
                }
                link_user = str(user_id);
            }
            callback = str(
                get_scale_config().get_sso_config().get('client_auth_callback_url')
                    or ''
            );
            if mode == "web" and not callback {
                return TransportResponse.fail(
                    code="SSO_NOT_CONFIGURED",
                    message="Configure client_auth_callback_url for client-managed OAuth"
                );
            }
            result = session.begin(challenge, mode, link_user, callback, True);
            return TransportResponse.success(data=asdict(result));
        }
        async def oauth_finish(
            platform: str, code: str, state: str, verifier: str
        ) -> TransportResponse {
            session = configured_session(platform);
            if session is None {
                return TransportResponse.fail(
                    code="SSO_NOT_CONFIGURED", message="SSO provider is not configured"
                );
            }
            result = await session.finish(code, state, verifier);
            return TransportResponse.success(data=asdict(result));
        }
        def oauth_poll(platform: str, poll: str) -> TransportResponse {
            session = configured_session(platform);
            if session is None {
                return TransportResponse.fail(
                    code="SSO_NOT_CONFIGURED", message="SSO provider is not configured"
                );
            }
            return TransportResponse.success(data=asdict(session.poll(poll)));
        }
        for (path, callback, names) in [
            ("begin", oauth_begin, ["challenge", "mode"]),
            ("finish", oauth_finish, ["code", "state", "verifier"]),
            ("poll", oauth_poll, ["poll"])
        ] {
            server.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.POST,
                    path="/sso/{platform}/" + path,
                    callback=callback,
                    parameters=[platform_param]
                        + [
                            APIParameter(
                                name=name,
                                data_type="string",
                                required=name != "mode",
                                kind=ParameterType.BODY
                            ) for name in names
                        ],
                    tags=["SSO APIs"],
                    summary="OAuth session " + path
                )
            );
        }

        async def sso_callback(
            request: Request, platform: str
        ) -> (Response | TransportResponse) {
            session = configured_session(platform);
            state = OAuth2CodeProvider._callback_param(request, 'state') or '';
            record = session.record(state) if session is not None else None;
            state_data = json.loads(record['identity_value']) if record else {};
            if session is not None
                and state_data.get('client_managed')
                and state_data.get('mode') == 'web' {
                target = str(state_data.get('client_callback') or '');
                suffix = '&' if '?' in target else '?';
                code = OAuth2CodeProvider._callback_param(request, 'code') or '';
                denied = OAuth2CodeProvider._callback_param(request, 'error') or '';
                return RedirectResponse(
                    url=target
                        + suffix
                        + 'code='
                        + quote(code)
                        + '&state='
                        + quote(state)
                        + '&error='
                        + quote(denied),
                    headers={
                        'Cache-Control': 'no-store',
                        'Referrer-Policy': 'no-referrer'
                    }
                );
            }
            if session is not None and session.callback_mode(state) == 'native' {
                message = await session.complete_native(
                    OAuth2CodeProvider._callback_param(request, 'code') or '', state
                );
                return Response(
                    content=message,
                    headers={
                        'Cache-Control': 'no-store',
                        'Referrer-Policy': 'no-referrer'
                    }
                );
            }
            result = await sso.sso_callback(request, platform);
            sso_config = get_scale_config().get_sso_config();
            configured_url = str(sso_config.get('client_auth_callback_url', ''));
            requested_url = str(result.meta.extra.get('client_callback') or '')
                if result.meta
                else '';
            frontend_url = resolve_sso_client_redirect(requested_url, configured_url);
            if not frontend_url {
                return result;
            }
            if result.ok {
                token = result.data.get('token', '') if result.data else '';
                return RedirectResponse(url=f"{frontend_url}?token={token}");
            }
            error_code = result.error.code if result.error else 'UNKNOWN_ERROR';
            message = result.error.message if result.error else 'Unknown error';
            return RedirectResponse(
                url=f"{frontend_url}?error={quote(error_code)}&message={quote(message)}"
            );
        }
        for method in (HTTPMethod.GET, HTTPMethod.POST) {
            server.add_endpoint(
                JEndPoint(
                    method=method,
                    path='/sso/{platform}/callback',
                    callback=sso_callback,
                    parameters=[platform_param],
                    tags=['SSO APIs'],
                    summary=f"SSO callback ({method.value})",
                    description='Handles the callback from the SSO provider after authentication.'
                )
            );
        }

        async def firebase_token(body_data: FirebaseTokenRequest) -> TransportResponse {
            return await sso.firebase_token_auth_with_id_token(body_data.id_token);
        }
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path='/sso/firebase/token',
                callback=firebase_token,
                request_model=FirebaseTokenRequest,
                tags=['SSO APIs'],
                summary='Firebase Auth token verification',
                description='Verify a Firebase ID token and log in or auto-register the user. Firebase has no redirect flow: the client SDK authenticates and hands over the ID token.'
            )
        );
    }
}


obj ApiKeyExtension(ServerExtension) {
    has manager: (ApiKeyManager | None) = None;

    def api_keys -> ApiKeyManager {
        if self.manager is None {
            self.manager = ApiKeyManager();
        }
        return self.manager;
    }

    def register(server: JacAPIServer) {
        keys = self.api_keys;

        async def create_api_key(
            request: Request,
            name: str,
            expiry_days: (int | None) = None,
            allowed_walkers: (str | None) = None
        ) -> TransportResponse {
            (user_id, error) = require_user(request);
            if error is not None {
                return error;
            }
            scoped: (list[str] | None) = None;
            if allowed_walkers {
                scoped = [
                    w.strip()
                    for w in allowed_walkers.split(',')
                    if w.strip()
                ];
            }
            return keys().create_api_key(
                user_id=str(user_id),
                name=name,
                expiry_days=expiry_days,
                allowed_walkers=scoped
            );
        }
        async def list_api_keys(request: Request) -> TransportResponse {
            (user_id, error) = require_user(request);
            if error is not None {
                return error;
            }
            return keys().list_api_keys(str(user_id));
        }
        async def revoke_api_key(
            request: Request, api_key_id: str
        ) -> TransportResponse {
            (user_id, error) = require_user(request);
            if error is not None {
                return error;
            }
            return keys().revoke_api_key(str(user_id), api_key_id);
        }
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path='/api-key/create',
                callback=create_api_key,
                parameters=[
                    APIParameter(
                        name='name',
                        data_type='string',
                        required=True,
                        description='A friendly name for the API key',
                        kind=ParameterType.BODY
                    ),
                    APIParameter(
                        name='expiry_days',
                        data_type='integer',
                        required=False,
                        description='Days until expiry (default from config)',
                        kind=ParameterType.BODY
                    ),
                    APIParameter(
                        name='allowed_walkers',
                        data_type='string',
                        required=False,
                        default_value='',
                        description='Comma-separated webhook walker names this key may call; empty for an unscoped key.',
                        kind=ParameterType.BODY
                    )
                ],
                tags=['API Keys'],
                summary='Create a new API key',
                description='Creates an API key for webhook authentication.',
                requires_auth=True
            )
        );
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/api-key/list',
                callback=list_api_keys,
                parameters=[],
                tags=['API Keys'],
                summary='List API keys',
                requires_auth=True
            )
        );
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.DELETE,
                path='/api-key/{api_key_id}',
                callback=revoke_api_key,
                parameters=[
                    APIParameter(
                        name='api_key_id',
                        data_type='string',
                        required=True,
                        description='The ID of the API key to revoke',
                        kind=ParameterType.PATH
                    )
                ],
                tags=['API Keys'],
                summary='Revoke an API key',
                requires_auth=True
            )
        );
    }
}
