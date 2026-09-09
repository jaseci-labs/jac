import json;
import logging;
import time;
import from jaclang.runtime.builtin { APIProtocol }
import from jaclang.server.server { JacAPIServer, JsonValue, ServerExtension }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.server.transport { Meta, TransportResponse }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.webhook.webhook { ApiKeyManager, WebhookUtils }

glob logger: logging.Logger = logging.getLogger(__name__);


def _fail(code: str, message: str, status: int) -> TransportResponse {
    return TransportResponse.fail(
        code=code, message=message, meta=Meta(extra={'http_status': status})
    );
}


obj WebhookExtension(ServerExtension) {
    has manager: (ApiKeyManager | None) = None;

    def api_keys -> ApiKeyManager {
        if self.manager is None {
            self.manager = ApiKeyManager();
        }
        return self.manager;
    }

    def webhook_parameters(
        server: JacAPIServer, walker_name: str
    ) -> list[APIParameter] {
        parameters: list[APIParameter] = [
            APIParameter(
                name='x_api_key',
                data_type='string',
                required=True,
                description='API key for webhook authentication (X-API-Key header)',
                kind=ParameterType.HEADER
            ),
            APIParameter(
                name='x_webhook_signature',
                data_type='string',
                required=False,
                description='HMAC-SHA256 of "<timestamp>." + body, keyed by the signing secret (X-Webhook-Signature header)',
                kind=ParameterType.HEADER
            ),
            APIParameter(
                name='x_webhook_timestamp',
                data_type='string',
                required=False,
                description='Unix timestamp (seconds) bound into the signature (X-Webhook-Timestamp header)',
                kind=ParameterType.HEADER
            )
        ];
        fields = server.introspector.introspect_walker(
            server.get_walkers()[walker_name]
        )['fields'];
        for field_name in fields {
            if field_name == '_jac_spawn_node' {
                continue;
            }
            parameters.append(
                APIParameter(
                    name=field_name,
                    data_type=fields[field_name]['type'],
                    required=fields[field_name]['required'],
                    default_value=fields[field_name]['default'],
                    description=f"Field {field_name} for webhook walker {walker_name}",
                    kind=ParameterType.BODY
                )
            );
        }
        return parameters;
    }

    def webhook_callback(
        server: JacAPIServer, walker_name: str
    ) -> Callable[..., TransportResponse] {
        keys = self.api_keys;

        async def _process(request: Request) -> TransportResponse {
            cfg = get_scale_config().get_webhook_config();
            signature_header = cfg.get('signature_header', 'X-Webhook-Signature');
            timestamp_header = cfg.get('timestamp_header', 'X-Webhook-Timestamp');
            verify_signature = cfg.get('verify_signature', True);
            replay_tolerance = int(cfg.get('replay_tolerance_seconds', 300));
            max_body_bytes = int(cfg.get('max_body_bytes', 1048576));
            rate_limit = int(cfg.get('rate_limit_per_minute', 0));

            api_key = request.headers.get('X-API-Key');
            if not api_key {
                return _fail('UNAUTHORIZED', 'Missing X-API-Key header', 401);
            }
            key_doc = keys().resolve_key(api_key);
            if key_doc is None {
                return _fail('UNAUTHORIZED', 'Invalid or expired API key', 401);
            }
            user_id: str = str(key_doc.get('user_id') or '');
            if not user_id or not server.user_manager.user_exists(user_id) {
                return _fail('UNAUTHORIZED', 'Invalid or expired API key', 401);
            }
            allowed_walkers: list[str] = list(key_doc.get('allowed_walkers') or []);
            if allowed_walkers and walker_name not in allowed_walkers {
                return _fail(
                    'FORBIDDEN', 'API key is not permitted to call this webhook', 403
                );
            }
            api_key_id: str = str(key_doc.get('api_key_id') or '');
            if not keys().check_rate_limit(api_key_id, rate_limit) {
                return _fail('RATE_LIMITED', 'Rate limit exceeded', 429);
            }
            raw_body = request.body;
            if len(raw_body) > max_body_bytes {
                return _fail('PAYLOAD_TOO_LARGE', 'Request body too large', 413);
            }
            if verify_signature {
                signature = request.headers.get(signature_header);
                if not signature {
                    return _fail(
                        'UNAUTHORIZED', f"Missing {signature_header} header", 401
                    );
                }
                timestamp = request.headers.get(timestamp_header);
                if not timestamp {
                    return _fail(
                        'UNAUTHORIZED', f"Missing {timestamp_header} header", 401
                    );
                }
                try {
                    request_ts = int(timestamp);
                } except ValueError {
                    return _fail('UNAUTHORIZED', 'Invalid webhook timestamp', 401);
                }
                if abs(int(time.time()) - request_ts) > replay_tolerance {
                    return _fail(
                        'UNAUTHORIZED', 'Webhook timestamp outside allowed window', 401
                    );
                }
                signing_secret: str = str(key_doc.get('signing_secret') or '');
                if not signing_secret {
                    return _fail('UNAUTHORIZED', 'Invalid webhook signature', 401);
                }
                signed_payload = f"{timestamp}.".encode('utf-8') + raw_body;
                if not WebhookUtils.verify_signature(
                    signed_payload,
                    WebhookUtils.extract_signature(signature),
                    signing_secret
                ) {
                    return _fail('UNAUTHORIZED', 'Invalid webhook signature', 401);
                }
            }
            try {
                body_data = json.loads(raw_body) if raw_body else {};
            } except ValueError {
                body_data = {};
            }
            fields = server.introspector.introspect_walker(
                server.get_walkers()[walker_name]
            )['fields'];
            walker_kwargs: dict[str, any] = {};
            if isinstance(body_data, dict) {
                for (field_name, value) in body_data.items() {
                    if field_name in fields and field_name != '_jac_spawn_node' {
                        walker_kwargs[field_name] = value;
                    }
                }
            }
            result = await server.execution_manager.spawn_walker(
                server.get_walkers()[walker_name], walker_kwargs, user_id
            );
            if isinstance(result, dict) and 'error' in result {
                logger.error(
                    f"Webhook walker '{walker_name}' failed: "
                    f"{result.get('error')} {result.get('traceback') or ''}"
                );
                return _fail('EXECUTION_ERROR', 'Webhook processing failed', 500);
            }
            return TransportResponse.success(
                data=result, meta=Meta(extra={'http_status': 200})
            );
        }

        async def callback(request: Request, **kwargs: JsonValue) -> TransportResponse {
            resp = await _process(request);
            status = resp.meta.extra.get('http_status') if resp?.meta else None;
            outcome = 'ok'
                if resp.ok
                else (resp.error.code if resp?.error else 'error');
            line = (
                f"webhook audit walker={walker_name} ip={request.client_host or '-'} "
                f"status={status} outcome={outcome}"
            );
            if resp.ok {
                logger.info(line);
            } else {
                logger.warning(line);
            }
            return resp;
        }
        return callback;
    }

    def register(server: JacAPIServer) {
        registered = False;
        for walker_name in list(server.get_walkers()) {
            if server.introspector.walker_protocol(walker_name)
                != APIProtocol.WEBHOOK {
                continue;
            }
            registered = True;
            server.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.POST,
                    path=f"/webhook/{walker_name}",
                    callback=self.webhook_callback(server, walker_name),
                    parameters=self.webhook_parameters(server, walker_name),
                    tags=['Webhooks'],
                    summary=f"Webhook endpoint for {walker_name}",
                    description=f"Webhook for {walker_name}: API key plus HMAC-SHA256 signature."
                )
            );
        }
        if registered {
            self.api_keys();
        }
    }
}
