"""Admin Portal Implementation for JAC-Scale."""
import logging;
import from collections.abc { Callable }
import from typing { Any }
import from fastapi { Request }
import from fastapi.responses { HTMLResponse, JSONResponse, Response, FileResponse, RedirectResponse }
import mimetypes;
import subprocess;
import from pathlib { Path }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jaclang.runtimelib.server { JsonValue }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint, APIParameter, ParameterType }
import from jac_scale.config_loader { get_scale_config }
import from jac_scale.user_manager { UserRole }
import from jaclang.jac0core.runtime { JacRuntime as Jac }

glob logger = logging.getLogger(__name__);

"""Register all admin endpoints."""
impl JacAPIServerAdmin.register_admin_endpoints -> None {
    admin_config = get_scale_config().get_admin_config();
    if not admin_config.get('enabled', True) {
        logger.info("Admin portal is disabled");
        return;
    }

    # Bootstrap admin user
    self.bootstrap_admin();

    # Admin login endpoint
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/admin/login',
            callback=self.admin_login,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Admin username',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='password',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Admin password',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Admin login',
            description='Authenticate as admin user'
        )
    );

    # Password reset endpoint (for users who require password reset)
    import from fastapi { Request }
    async def reset_password_handler(
        request: Request, current_password: str, new_password: str
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.reset_password(current_password, new_password, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/admin/reset-password',
            callback=reset_password_handler,
            parameters=[
                APIParameter(
                    name='current_password',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Current password',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='new_password',
                    data_type='string',
                    required=True,
                    default=None,
                    description='New password',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Reset password',
            description='Reset password for users requiring password change'
        )
    );

    # User management endpoints
    async def list_users_handler(
        request: Request, limit: int = 100, offset: int = 0
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_list_users(limit, offset, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/users',
            callback=list_users_handler,
            parameters=[
                APIParameter(
                    name='limit',
                    data_type='integer',
                    required=False,
                    default=100,
                    description='Max users to return',
                    type=ParameterType.QUERY
                ),
                APIParameter(
                    name='offset',
                    data_type='integer',
                    required=False,
                    default=0,
                    description='Offset for pagination',
                    type=ParameterType.QUERY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='List users',
            description='List all users (admin only)'
        )
    );

    async def get_user_handler(request: Request, username: str) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_get_user(username, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/users/{username}',
            callback=get_user_handler,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Username to get',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Get user',
            description='Get user details (admin only)'
        )
    );

    async def create_user_handler(
        request: Request, username: str, password: str, role: str = 'user'
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_create_user(username, password, role, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/admin/users',
            callback=create_user_handler,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Username for new user',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='password',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Password for new user',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='role',
                    data_type='string',
                    required=False,
                    default='user',
                    description='Role for new user (admin, moderator, user)',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Create user',
            description='Create a new user (admin only). User will be required to reset password on first login.'
        )
    );

    async def update_user_handler(
        request: Request,
        username: str,
        role: str | None = None,
        requires_password_reset: bool | None = None
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_update_user(username, role, requires_password_reset, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path='/admin/users/{username}',
            callback=update_user_handler,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Username to update',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='role',
                    data_type='string',
                    required=False,
                    default=None,
                    description='New role (admin, moderator, user)',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='requires_password_reset',
                    data_type='boolean',
                    required=False,
                    default=None,
                    description='Force password reset on next login',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Update user',
            description='Update user role or settings (admin only)'
        )
    );

    async def delete_user_handler(request: Request, username: str) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_delete_user(username, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.DELETE,
            path='/admin/users/{username}',
            callback=delete_user_handler,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Username to delete',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Delete user',
            description='Delete a user (admin only)'
        )
    );

    # SSO management endpoints
    async def list_sso_providers_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_list_sso_providers(authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/sso/providers',
            callback=list_sso_providers_handler,
            parameters=[],
            response_model=None,
            tags=['Admin'],
            summary='List SSO providers',
            description='List configured SSO providers (admin only)'
        )
    );

    async def get_user_sso_handler(request: Request, username: str) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_get_user_sso_accounts(username, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/users/{username}/sso',
            callback=get_user_sso_handler,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Username',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Get user SSO accounts',
            description='Get SSO accounts linked to a user (admin only)'
        )
    );

    # Admin graph visualization
    async def admin_graph_handler(
        request: Request, username: str | None = None
    ) -> JSONResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_graph_data(username, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/graph',
            callback=admin_graph_handler,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=False,
                    default=None,
                    description='Username to view graph for (defaults to all users)',
                    type=ParameterType.QUERY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Admin graph data',
            description='Get graph data for any user (admin only)'
        )
    );

    # Admin UI - redirect /admin to /admin/
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin',
            callback=self.serve_admin_page,
            parameters=[],
            response_model=None,
            tags=['Admin'],
            summary='Admin Portal Redirect',
            description='Redirect to /admin/'
        )
    );

    # Admin UI - serve index.html at /admin/
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/',
            callback=self.serve_admin_index,
            parameters=[],
            response_model=None,
            tags=['Admin'],
            summary='Admin Portal',
            description='Admin portal UI'
        )
    );

    # Admin static assets
    async def serve_admin_catchall_handler(request: Request, path: str) -> Response {
        return self.serve_admin_asset(path);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/{path:path}',
            callback=serve_admin_catchall_handler,
            parameters=[
                APIParameter(
                    name='path',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Asset path',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Admin static assets',
            description='Serve admin portal static assets'
        )
    );

    logger.info("Admin portal endpoints registered at /admin");
}

"""Bootstrap admin user on server start."""
impl JacAPIServerAdmin.bootstrap_admin -> None {
    result = self.user_manager.bootstrap_admin_user();
    if 'error' not in result {
        if 'created' in result.get('message', '').lower() {
            logger.warning(
                f"Admin user created with default credentials. "
                "Please change the password immediately!"
            );
        }
    }
}

"""Validate admin token and return username if valid admin."""
impl JacAPIServerAdmin.validate_admin_token(Authorization: str | None) -> (str | None) {
    if not Authorization or not Authorization.startswith('Bearer ') {
        return None;
    }
    token = Authorization[7:];
    username = self.user_manager.validate_jwt_token(token);
    if not username {
        return None;
    }
    if not self.user_manager.is_admin(username) {
        return None;
    }
    return username;
}

"""Check if request is from admin, return error response if not."""
impl JacAPIServerAdmin.require_admin(Authorization: str | None) -> TransportResponse | None {
    admin_user = self.validate_admin_token(Authorization);
    if not admin_user {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Admin access required',
            meta=Meta(extra={'http_status': 403})
        );
    }
    return None;
}

"""Admin login endpoint."""
impl JacAPIServerAdmin.admin_login(username: str, password: str) -> TransportResponse {
    if not username or not password {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }

    result = self.user_manager.authenticate(username, password);
    if not result {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid credentials',
            meta=Meta(extra={'http_status': 401})
        );
    }

    # Check if user is admin
    if not self.user_manager.is_admin(username) {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Admin access required',
            meta=Meta(extra={'http_status': 403})
        );
    }

    # Check if password reset is required
    requires_reset = self.user_manager.requires_password_reset(username);

    token = self.user_manager.create_jwt_token(username);
    return TransportResponse.success(
        data={
            'message': 'Login successful',
            'token': token,
            'username': username,
            'role': 'admin',
            'requires_password_reset': requires_reset
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""Reset password endpoint."""
impl JacAPIServerAdmin.reset_password(
    current_password: str,
    new_password: str,
    Authorization: str | None = None
) -> TransportResponse {
    # Validate token
    if not Authorization or not Authorization.startswith('Bearer ') {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Authentication required',
            meta=Meta(extra={'http_status': 401})
        );
    }
    token = Authorization[7:];
    username = self.user_manager.validate_jwt_token(token);
    if not username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid or expired token',
            meta=Meta(extra={'http_status': 401})
        );
    }

    if not current_password or not new_password {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Current and new password required',
            meta=Meta(extra={'http_status': 400})
        );
    }

    if len(new_password) < 8 {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Password must be at least 8 characters',
            meta=Meta(extra={'http_status': 400})
        );
    }

    # Update password
    result = self.user_manager.update_password(username, current_password, new_password);
    if 'error' in result {
        return TransportResponse.fail(
            code='UPDATE_FAILED',
            message=result.get('error', 'Password update failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }

    # Clear the requires_password_reset flag
    self.user_manager.set_requires_password_reset(username, False);

    # Generate new token
    new_token = self.user_manager.create_jwt_token(username);

    return TransportResponse.success(
        data={
            'message': 'Password updated successfully',
            'token': new_token
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""List all users (admin only)."""
impl JacAPIServerAdmin.admin_list_users(
    limit: int = 100, offset: int = 0, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }

    users = self.user_manager.list_all_users(limit, offset);
    return TransportResponse.success(
        data={'users': users, 'count': len(users), 'limit': limit, 'offset': offset},
        meta=Meta(extra={'http_status': 200})
    );
}

"""Get user details (admin only)."""
impl JacAPIServerAdmin.admin_get_user(
    username: str, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }

    user = self.user_manager.get_user(username);
    if not user {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message='User not found',
            meta=Meta(extra={'http_status': 404})
        );
    }

    # Get additional user info
    role = self.user_manager.get_user_role(username);
    requires_reset = self.user_manager.requires_password_reset(username);
    is_pwd_required = self.user_manager.is_password_required(username);
    sso_accounts = self.user_manager.get_sso_accounts(username);

    return TransportResponse.success(
        data={
            'username': username,
            'root_id': user.get('root_id'),
            'role': role or 'user',
            'requires_password_reset': requires_reset,
            'is_password_required': is_pwd_required,
            'sso_accounts': sso_accounts
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""Create user (admin only)."""
impl JacAPIServerAdmin.admin_create_user(
    username: str,
    password: str,
    role: str = 'user',
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }

    if not username or not password {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }

    result = self.user_manager.create_user_as_admin(
        username=username,
        password=password,
        role=role,
        requires_password_reset=True
    );

    if 'error' in result {
        return TransportResponse.fail(
            code='CREATE_FAILED',
            message=result.get('error', 'User creation failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }

    return TransportResponse.success(
        data=result,
        meta=Meta(extra={'http_status': 201})
    );
}

"""Update user (admin only)."""
impl JacAPIServerAdmin.admin_update_user(
    username: str,
    role: str | None = None,
    requires_password_reset: bool | None = None,
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }

    user = self.user_manager.get_user(username);
    if not user {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message='User not found',
            meta=Meta(extra={'http_status': 404})
        );
    }

    updates = [];

    if role is not None {
        result = self.user_manager.set_user_role(username, role);
        if 'error' in result {
            return TransportResponse.fail(
                code='UPDATE_FAILED',
                message=result.get('error', 'Role update failed'),
                meta=Meta(extra={'http_status': 400})
            );
        }
        updates.append(f"role set to '{role}'");
    }

    if requires_password_reset is not None {
        result = self.user_manager.set_requires_password_reset(username, requires_password_reset);
        if 'error' in result {
            return TransportResponse.fail(
                code='UPDATE_FAILED',
                message=result.get('error', 'Password reset flag update failed'),
                meta=Meta(extra={'http_status': 400})
            );
        }
        updates.append(f"requires_password_reset set to {requires_password_reset}");
    }

    if not updates {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='No updates provided',
            meta=Meta(extra={'http_status': 400})
        );
    }

    return TransportResponse.success(
        data={'message': 'User updated', 'updates': updates, 'username': username},
        meta=Meta(extra={'http_status': 200})
    );
}

"""Delete user (admin only)."""
impl JacAPIServerAdmin.admin_delete_user(
    username: str, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }

    result = self.user_manager.delete_user(username);
    if 'error' in result {
        return TransportResponse.fail(
            code='DELETE_FAILED',
            message=result.get('error', 'User deletion failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }

    return TransportResponse.success(
        data=result,
        meta=Meta(extra={'http_status': 200})
    );
}

"""List SSO providers (admin only)."""
impl JacAPIServerAdmin.admin_list_sso_providers(
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }

    sso_config = get_scale_config().get_sso_config();
    providers = [];

    # Check each platform
    for platform in ['google'] {
        platform_config = sso_config.get(platform, {});
        client_id = platform_config.get('client_id', '');
        is_configured = bool(client_id);
        providers.append({
            'platform': platform,
            'configured': is_configured,
            'client_id_set': bool(client_id),
            'client_secret_set': bool(platform_config.get('client_secret', ''))
        });
    }

    return TransportResponse.success(
        data={
            'providers': providers,
            'sso_host': sso_config.get('host', ''),
            'client_auth_callback_url': sso_config.get('client_auth_callback_url', '')
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""Get user's SSO accounts (admin only)."""
impl JacAPIServerAdmin.admin_get_user_sso_accounts(
    username: str, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }

    user = self.user_manager.get_user(username);
    if not user {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message='User not found',
            meta=Meta(extra={'http_status': 404})
        );
    }

    accounts = self.user_manager.get_sso_accounts(username);
    return TransportResponse.success(
        data={'username': username, 'sso_accounts': accounts},
        meta=Meta(extra={'http_status': 200})
    );
}

"""Get graph data for admin visualization."""
impl JacAPIServerAdmin.admin_graph_data(
    username: str | None = None, Authorization: str | None = None
) -> JSONResponse {
    error = self.require_admin(Authorization);
    if error {
        return JSONResponse(
            status_code=403,
            content={'error': 'Forbidden', 'message': 'Admin access required'}
        );
    }

    import from jaclang.runtimelib.utils { collect_node_connections }

    target_username = username or '__guest__';
    root_id = self.user_manager.get_root_id(target_username);

    if not root_id {
        return JSONResponse(
            status_code=404,
            content={'error': 'Not found', 'message': f"User '{target_username}' not found or has no graph"}
        );
    }

    ctx = Jac.get_context();
    ctx.set_user_root(root_id);

    try {
        user_root = ctx.get_root();
        visited_nodes: set = set();
        connections: set = set();
        edge_ids: set = set();
        nodes: list[dict] = [];
        edges: list[dict] = [];

        collect_node_connections(user_root, visited_nodes, connections, edge_ids);

        nodes.append({'id': str(id(user_root)), 'label': 'root'});
        for node_arch in visited_nodes {
            if node_arch != user_root {
                nodes.append({'id': str(id(node_arch)), 'label': repr(node_arch)});
            }
        }
        for (_, source_node, target_node, edge_arch) in connections {
            edge_data: dict = {
                'from': str(id(source_node)),
                'to': str(id(target_node))
            };
            if repr(edge_arch) != 'GenericEdge()' {
                edge_data['label'] = repr(edge_arch);
            }
            edges.append(edge_data);
        }

        return JSONResponse(
            status_code=200,
            content={
                'version': '1.0',
                'username': target_username,
                'nodes': nodes,
                'edges': edges
            }
        );
    } except Exception as e {
        return JSONResponse(
            status_code=500,
            content={'error': 'Internal error', 'message': str(e)}
        );
    }
}

"""Get the admin dist directory path - in the running app's .jac folder."""
impl JacAPIServerAdmin.get_admin_dist_dir -> Path {
    import os;
    # Use the current working directory (where the app is being run from)
    cwd = Path(os.getcwd());
    return cwd / ".jac" / "admin";
}

"""Build the admin client from admin/ui source."""
impl JacAPIServerAdmin.build_admin_client(force: bool = False) -> bool {
    dist_dir = self.get_admin_dist_dir();
    index_file = dist_dir / "index.html";

    # Check if already built
    if not force and index_file.exists() {
        logger.debug("Admin client already built");
        return True;
    }

    # Get admin UI source directory
    import from jac_scale.admin { admin_portal }
    admin_dir = Path(admin_portal.__file__).parent;
    ui_dir = admin_dir / "ui";

    if not (ui_dir / "main.jac").exists() {
        logger.error(f"Admin UI source not found at {ui_dir}");
        return False;
    }

    logger.info("Building admin client...");

    try {
        # Run jac build in the UI directory
        result = subprocess.run(
            ["jac", "build", "main.jac"],
            cwd=str(ui_dir),
            capture_output=True,
            text=True,
            timeout=300
        );

        if result.returncode != 0 {
            logger.error(f"Admin client build failed: {result.stderr}");
            return False;
        }

        # Copy built files to .jac/admin
        ui_dist = ui_dir / ".jac" / "client" / "dist";
        if ui_dist.exists() {
            import shutil;
            dist_dir.mkdir(parents=True, exist_ok=True);
            for item in ui_dist.iterdir() {
                dest = dist_dir / item.name;
                if item.is_dir() {
                    if dest.exists() {
                        shutil.rmtree(dest);
                    }
                    shutil.copytree(item, dest);
                } else {
                    shutil.copy2(item, dest);
                }
            }
        }

        logger.info("Admin client built successfully");
        return True;
    } except subprocess.TimeoutExpired {
        logger.error("Admin client build timed out");
        return False;
    } except Exception as e {
        logger.error(f"Admin client build error: {e}");
        return False;
    }
}

"""Redirect /admin to /admin/."""
impl JacAPIServerAdmin.serve_admin_page -> Response {
    return RedirectResponse(url="/admin/", status_code=302);
}

"""Serve the admin portal index.html."""
impl JacAPIServerAdmin.serve_admin_index -> Response {
    dist_dir = self.get_admin_dist_dir();
    index_file = dist_dir / "index.html";

    # Build if not available
    if not index_file.exists() {
        if not self.build_admin_client() {
            return HTMLResponse(
                content='''<!DOCTYPE html>
<html>
<head><title>Admin Portal - Build Error</title></head>
<body style="background:#0f172a;color:#e2e8f0;font-family:system-ui;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0">
<div style="text-align:center">
<h1 style="color:#ef4444">Admin Portal Build Failed</h1>
<p>The admin client could not be built. Check the server logs for details.</p>
</div>
</body>
</html>''',
                status_code=503
            );
        }
    }

    return FileResponse(path=str(index_file), media_type="text/html");
}

"""Serve admin portal static assets."""
impl JacAPIServerAdmin.serve_admin_asset(path: str) -> Response {
    dist_dir = self.get_admin_dist_dir();

    # Check if this is a static asset request
    has_extension = '.' in path.split('/')[-1] if path else False;

    if has_extension {
        asset_path = dist_dir / path;

        # Security: ensure path doesn't escape dist directory
        try {
            asset_path = asset_path.resolve();
            dist_resolved = dist_dir.resolve();
            if not str(asset_path).startswith(str(dist_resolved)) {
                return Response(content="Forbidden", status_code=403);
            }
        } except Exception {
            return Response(content="Invalid path", status_code=400);
        }

        if asset_path.exists() {
            guess_result = mimetypes.guess_type(str(asset_path));
            content_type = guess_result[0] if guess_result[0] else "application/octet-stream";
            return FileResponse(path=str(asset_path), media_type=content_type);
        }
    }

    # For non-asset paths (SPA routes), serve index.html
    index_file = dist_dir / "index.html";
    if not index_file.exists() {
        if not self.build_admin_client() {
            return Response(content="Admin client not available", status_code=503);
        }
    }

    if index_file.exists() {
        return FileResponse(path=str(index_file), media_type="text/html");
    }

    return Response(content="Not found", status_code=404);
}

# Legacy inline HTML fallback - keeping for reference
glob _ADMIN_HTML_FALLBACK = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>JAC Admin Portal</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0f172a;
            color: #e2e8f0;
            min-height: 100vh;
        }
        .header {
            background: #1e293b;
            padding: 16px 24px;
            border-bottom: 1px solid #334155;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .logo {
            font-size: 20px;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .logo svg { color: #f59e0b; }
        .user-info {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        .user-badge {
            background: #14532d;
            color: #4ade80;
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }
        .btn {
            padding: 8px 16px;
            border-radius: 6px;
            border: 1px solid #334155;
            background: #1e293b;
            color: #e2e8f0;
            cursor: pointer;
            font-size: 14px;
            transition: all 0.15s;
        }
        .btn:hover { background: #334155; }
        .btn-primary { background: #3b82f6; border-color: #3b82f6; }
        .btn-primary:hover { background: #2563eb; }
        .btn-danger { border-color: #ef4444; color: #ef4444; }
        .btn-danger:hover { background: #ef4444; color: #fff; }
        .container { max-width: 1200px; margin: 0 auto; padding: 24px; }
        .card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
        }
        .card-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 16px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .stat-card {
            background: #0f172a;
            border: 1px solid #334155;
            border-radius: 8px;
            padding: 16px;
        }
        .stat-value { font-size: 32px; font-weight: 700; color: #3b82f6; }
        .stat-label { font-size: 14px; color: #94a3b8; margin-top: 4px; }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            text-align: left;
            padding: 12px;
            border-bottom: 1px solid #334155;
        }
        th { color: #94a3b8; font-weight: 500; font-size: 13px; }
        .role-badge {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 500;
        }
        .role-admin { background: #7c3aed20; color: #a78bfa; }
        .role-moderator { background: #0ea5e920; color: #38bdf8; }
        .role-user { background: #64748b20; color: #94a3b8; }
        .reset-badge {
            background: #f59e0b20;
            color: #fbbf24;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 11px;
        }
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.7);
            align-items: center;
            justify-content: center;
            z-index: 100;
        }
        .modal.open { display: flex; }
        .modal-content {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 12px;
            padding: 24px;
            width: 400px;
            max-width: 90vw;
        }
        .modal-title { font-size: 18px; font-weight: 600; margin-bottom: 16px; }
        .form-group { margin-bottom: 16px; }
        .form-group label { display: block; font-size: 13px; color: #94a3b8; margin-bottom: 6px; }
        .form-group input, .form-group select {
            width: 100%;
            padding: 10px 12px;
            border: 1px solid #334155;
            border-radius: 6px;
            background: #0f172a;
            color: #e2e8f0;
            font-size: 14px;
        }
        .form-group input:focus, .form-group select:focus {
            outline: none;
            border-color: #3b82f6;
        }
        .form-actions { display: flex; gap: 12px; justify-content: flex-end; margin-top: 20px; }
        .alert {
            padding: 12px 16px;
            border-radius: 8px;
            margin-bottom: 16px;
            display: none;
        }
        .alert-error { background: #ef444420; border: 1px solid #ef4444; color: #fca5a5; }
        .alert-success { background: #22c55e20; border: 1px solid #22c55e; color: #86efac; }
        .login-container {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 12px;
            padding: 32px;
            width: 400px;
        }
        .login-card .logo { justify-content: center; font-size: 24px; margin-bottom: 24px; }
        .tabs { display: flex; gap: 8px; margin-bottom: 16px; }
        .tab {
            padding: 8px 16px;
            border-radius: 6px;
            background: transparent;
            color: #94a3b8;
            border: none;
            cursor: pointer;
            font-size: 14px;
        }
        .tab.active { background: #334155; color: #e2e8f0; }
        .hidden { display: none !important; }
    </style>
</head>
<body>
    <!-- Login Screen -->
    <div id="login-screen" class="login-container">
        <div class="login-card">
            <div class="logo">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2L2 7l10 5 10-5-10-5z"/>
                    <path d="M2 17l10 5 10-5"/>
                    <path d="M2 12l10 5 10-5"/>
                </svg>
                JAC Admin
            </div>
            <div id="login-alert" class="alert alert-error"></div>
            <div class="form-group">
                <label>Username</label>
                <input type="text" id="login-username" placeholder="admin">
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" id="login-password" placeholder="Enter password">
            </div>
            <button class="btn btn-primary" style="width:100%" onclick="login()">Sign In</button>
        </div>
    </div>

    <!-- Password Reset Screen -->
    <div id="reset-screen" class="login-container hidden">
        <div class="login-card">
            <div class="logo">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                    <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                </svg>
                Password Reset Required
            </div>
            <p style="color:#94a3b8;margin-bottom:20px;text-align:center">You must change your password before continuing.</p>
            <div id="reset-alert" class="alert alert-error"></div>
            <div class="form-group">
                <label>Current Password</label>
                <input type="password" id="reset-current" placeholder="Current password">
            </div>
            <div class="form-group">
                <label>New Password</label>
                <input type="password" id="reset-new" placeholder="New password (min 8 chars)">
            </div>
            <div class="form-group">
                <label>Confirm New Password</label>
                <input type="password" id="reset-confirm" placeholder="Confirm new password">
            </div>
            <button class="btn btn-primary" style="width:100%" onclick="resetPassword()">Change Password</button>
        </div>
    </div>

    <!-- Main Admin Screen -->
    <div id="admin-screen" class="hidden">
        <div class="header">
            <div class="logo">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2L2 7l10 5 10-5-10-5z"/>
                    <path d="M2 17l10 5 10-5"/>
                    <path d="M2 12l10 5 10-5"/>
                </svg>
                JAC Admin Portal
            </div>
            <div class="user-info">
                <span id="admin-username"></span>
                <span class="user-badge">ADMIN</span>
                <button class="btn btn-danger" onclick="logout()">Logout</button>
            </div>
        </div>
        <div class="container">
            <div id="main-alert" class="alert"></div>

            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-value" id="stat-users">-</div>
                    <div class="stat-label">Total Users</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="stat-admins">-</div>
                    <div class="stat-label">Admins</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="stat-sso">-</div>
                    <div class="stat-label">SSO Providers</div>
                </div>
            </div>

            <div class="card">
                <div class="card-title">
                    <span>Users</span>
                    <button class="btn btn-primary" onclick="openCreateUser()">+ Add User</button>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>Username</th>
                            <th>Role</th>
                            <th>Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="users-table"></tbody>
                </table>
            </div>

            <div class="card">
                <div class="card-title">SSO Providers</div>
                <table>
                    <thead>
                        <tr>
                            <th>Provider</th>
                            <th>Status</th>
                            <th>Configuration</th>
                        </tr>
                    </thead>
                    <tbody id="sso-table"></tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Create User Modal -->
    <div class="modal" id="create-user-modal">
        <div class="modal-content">
            <div class="modal-title">Create User</div>
            <div id="create-user-alert" class="alert alert-error"></div>
            <div class="form-group">
                <label>Username</label>
                <input type="text" id="new-username" placeholder="username">
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" id="new-password" placeholder="password">
            </div>
            <div class="form-group">
                <label>Role</label>
                <select id="new-role">
                    <option value="user">User</option>
                    <option value="moderator">Moderator</option>
                    <option value="admin">Admin</option>
                </select>
            </div>
            <div class="form-actions">
                <button class="btn" onclick="closeModal('create-user-modal')">Cancel</button>
                <button class="btn btn-primary" onclick="createUser()">Create</button>
            </div>
        </div>
    </div>

    <!-- Edit User Modal -->
    <div class="modal" id="edit-user-modal">
        <div class="modal-content">
            <div class="modal-title">Edit User: <span id="edit-username-display"></span></div>
            <div id="edit-user-alert" class="alert alert-error"></div>
            <input type="hidden" id="edit-username">
            <div class="form-group">
                <label>Role</label>
                <select id="edit-role">
                    <option value="user">User</option>
                    <option value="moderator">Moderator</option>
                    <option value="admin">Admin</option>
                </select>
            </div>
            <div class="form-group">
                <label>
                    <input type="checkbox" id="edit-reset-password">
                    Require password reset on next login
                </label>
            </div>
            <div class="form-actions">
                <button class="btn" onclick="closeModal('edit-user-modal')">Cancel</button>
                <button class="btn btn-primary" onclick="updateUser()">Save</button>
            </div>
        </div>
    </div>

    <script>
        const baseUrl = window.location.origin;
        let authToken = localStorage.getItem('admin_token');
        let currentUsername = localStorage.getItem('admin_username');
        let tempToken = null;

        // Check auth on load
        if (authToken) {
            showAdmin();
            loadData();
        }

        document.querySelectorAll('input').forEach(input => {
            input.addEventListener('keydown', e => {
                if (e.key === 'Enter') {
                    if (input.id.startsWith('login-')) login();
                    else if (input.id.startsWith('reset-')) resetPassword();
                }
            });
        });

        async function login() {
            const username = document.getElementById('login-username').value;
            const password = document.getElementById('login-password').value;
            const alert = document.getElementById('login-alert');
            alert.style.display = 'none';

            try {
                const resp = await fetch(baseUrl + '/admin/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username, password })
                });
                const data = await resp.json();
                if (data.ok && data.data) {
                    if (data.data.requires_password_reset) {
                        tempToken = data.data.token;
                        currentUsername = username;
                        showResetScreen();
                    } else {
                        authToken = data.data.token;
                        currentUsername = username;
                        localStorage.setItem('admin_token', authToken);
                        localStorage.setItem('admin_username', username);
                        showAdmin();
                        loadData();
                    }
                } else {
                    alert.textContent = data.error?.message || 'Login failed';
                    alert.style.display = 'block';
                }
            } catch (e) {
                alert.textContent = 'Connection error: ' + e.message;
                alert.style.display = 'block';
            }
        }

        function showResetScreen() {
            document.getElementById('login-screen').classList.add('hidden');
            document.getElementById('reset-screen').classList.remove('hidden');
            document.getElementById('admin-screen').classList.add('hidden');
        }

        async function resetPassword() {
            const current = document.getElementById('reset-current').value;
            const newPwd = document.getElementById('reset-new').value;
            const confirm = document.getElementById('reset-confirm').value;
            const alert = document.getElementById('reset-alert');
            alert.style.display = 'none';

            if (newPwd !== confirm) {
                alert.textContent = 'Passwords do not match';
                alert.style.display = 'block';
                return;
            }
            if (newPwd.length < 8) {
                alert.textContent = 'Password must be at least 8 characters';
                alert.style.display = 'block';
                return;
            }

            try {
                const resp = await fetch(baseUrl + '/admin/reset-password', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + tempToken
                    },
                    body: JSON.stringify({ current_password: current, new_password: newPwd })
                });
                const data = await resp.json();
                if (data.ok && data.data) {
                    authToken = data.data.token;
                    localStorage.setItem('admin_token', authToken);
                    localStorage.setItem('admin_username', currentUsername);
                    tempToken = null;
                    showAdmin();
                    loadData();
                } else {
                    alert.textContent = data.error?.message || 'Password reset failed';
                    alert.style.display = 'block';
                }
            } catch (e) {
                alert.textContent = 'Connection error: ' + e.message;
                alert.style.display = 'block';
            }
        }

        function showAdmin() {
            document.getElementById('login-screen').classList.add('hidden');
            document.getElementById('reset-screen').classList.add('hidden');
            document.getElementById('admin-screen').classList.remove('hidden');
            document.getElementById('admin-username').textContent = currentUsername;
        }

        function logout() {
            authToken = null;
            currentUsername = null;
            localStorage.removeItem('admin_token');
            localStorage.removeItem('admin_username');
            document.getElementById('admin-screen').classList.add('hidden');
            document.getElementById('login-screen').classList.remove('hidden');
        }

        async function loadData() {
            await Promise.all([loadUsers(), loadSSO()]);
        }

        async function loadUsers() {
            try {
                const resp = await fetch(baseUrl + '/admin/users', {
                    headers: { 'Authorization': 'Bearer ' + authToken }
                });
                const data = await resp.json();
                if (data.ok && data.data) {
                    const users = data.data.users;
                    document.getElementById('stat-users').textContent = users.length;
                    document.getElementById('stat-admins').textContent = users.filter(u => u.role === 'admin').length;

                    const tbody = document.getElementById('users-table');
                    tbody.innerHTML = users.map(u => `
                        <tr>
                            <td>${u.username}</td>
                            <td><span class="role-badge role-${u.role}">${u.role}</span></td>
                            <td>${u.requires_password_reset ? '<span class="reset-badge">Reset Required</span>' : 'Active'}</td>
                            <td>
                                <button class="btn" onclick="openEditUser('${u.username}', '${u.role}', ${u.requires_password_reset})">Edit</button>
                                <button class="btn btn-danger" onclick="deleteUser('${u.username}')">Delete</button>
                            </td>
                        </tr>
                    `).join('');
                }
            } catch (e) {
                console.error('Failed to load users:', e);
            }
        }

        async function loadSSO() {
            try {
                const resp = await fetch(baseUrl + '/admin/sso/providers', {
                    headers: { 'Authorization': 'Bearer ' + authToken }
                });
                const data = await resp.json();
                if (data.ok && data.data) {
                    const providers = data.data.providers;
                    document.getElementById('stat-sso').textContent = providers.filter(p => p.configured).length;

                    const tbody = document.getElementById('sso-table');
                    tbody.innerHTML = providers.map(p => `
                        <tr>
                            <td style="text-transform:capitalize">${p.platform}</td>
                            <td>${p.configured ? '<span style="color:#4ade80">Configured</span>' : '<span style="color:#94a3b8">Not Configured</span>'}</td>
                            <td>Client ID: ${p.client_id_set ? 'Set' : 'Not Set'}, Secret: ${p.client_secret_set ? 'Set' : 'Not Set'}</td>
                        </tr>
                    `).join('');
                }
            } catch (e) {
                console.error('Failed to load SSO:', e);
            }
        }

        function openCreateUser() {
            document.getElementById('new-username').value = '';
            document.getElementById('new-password').value = '';
            document.getElementById('new-role').value = 'user';
            document.getElementById('create-user-alert').style.display = 'none';
            document.getElementById('create-user-modal').classList.add('open');
        }

        function closeModal(id) {
            document.getElementById(id).classList.remove('open');
        }

        async function createUser() {
            const username = document.getElementById('new-username').value;
            const password = document.getElementById('new-password').value;
            const role = document.getElementById('new-role').value;
            const alert = document.getElementById('create-user-alert');
            alert.style.display = 'none';

            try {
                const resp = await fetch(baseUrl + '/admin/users', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + authToken
                    },
                    body: JSON.stringify({ username, password, role })
                });
                const data = await resp.json();
                if (data.ok) {
                    closeModal('create-user-modal');
                    loadUsers();
                    showAlert('User created successfully', 'success');
                } else {
                    alert.textContent = data.error?.message || 'Failed to create user';
                    alert.style.display = 'block';
                }
            } catch (e) {
                alert.textContent = 'Connection error: ' + e.message;
                alert.style.display = 'block';
            }
        }

        function openEditUser(username, role, requiresReset) {
            document.getElementById('edit-username').value = username;
            document.getElementById('edit-username-display').textContent = username;
            document.getElementById('edit-role').value = role;
            document.getElementById('edit-reset-password').checked = requiresReset;
            document.getElementById('edit-user-alert').style.display = 'none';
            document.getElementById('edit-user-modal').classList.add('open');
        }

        async function updateUser() {
            const username = document.getElementById('edit-username').value;
            const role = document.getElementById('edit-role').value;
            const requiresReset = document.getElementById('edit-reset-password').checked;
            const alert = document.getElementById('edit-user-alert');
            alert.style.display = 'none';

            try {
                const resp = await fetch(baseUrl + '/admin/users/' + encodeURIComponent(username), {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + authToken
                    },
                    body: JSON.stringify({ role, requires_password_reset: requiresReset })
                });
                const data = await resp.json();
                if (data.ok) {
                    closeModal('edit-user-modal');
                    loadUsers();
                    showAlert('User updated successfully', 'success');
                } else {
                    alert.textContent = data.error?.message || 'Failed to update user';
                    alert.style.display = 'block';
                }
            } catch (e) {
                alert.textContent = 'Connection error: ' + e.message;
                alert.style.display = 'block';
            }
        }

        async function deleteUser(username) {
            if (!confirm('Are you sure you want to delete user "' + username + '"?')) return;

            try {
                const resp = await fetch(baseUrl + '/admin/users/' + encodeURIComponent(username), {
                    method: 'DELETE',
                    headers: { 'Authorization': 'Bearer ' + authToken }
                });
                const data = await resp.json();
                if (data.ok) {
                    loadUsers();
                    showAlert('User deleted successfully', 'success');
                } else {
                    showAlert(data.error?.message || 'Failed to delete user', 'error');
                }
            } catch (e) {
                showAlert('Connection error: ' + e.message, 'error');
            }
        }

        function showAlert(message, type) {
            const alert = document.getElementById('main-alert');
            alert.textContent = message;
            alert.className = 'alert alert-' + type;
            alert.style.display = 'block';
            setTimeout(() => { alert.style.display = 'none'; }, 5000);
        }
    </script>
</body>
</html>''';
