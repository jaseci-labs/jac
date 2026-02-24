"""Admin Portal Implementation for JAC-Scale."""
import logging;
import from collections.abc { Callable }
import from typing { Any }
import from fastapi { Request }
import from fastapi.responses {
    HTMLResponse,
    JSONResponse,
    Response,
    FileResponse,
    RedirectResponse
}
import mimetypes;
import subprocess;
import from pathlib { Path }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jaclang.runtimelib.server { JsonValue }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
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
                    description='Role for new user (admin, user)',
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
        return self.admin_update_user(
            username, role, requires_password_reset, authorization
        );
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
                    description='New role (admin, user)',
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
    async def get_user_sso_handler(
        request: Request, username: str
    ) -> TransportResponse {
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
    # Configuration endpoints
    async def get_config_handler(
        request: Request, profile: str = "default"
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_get_config(profile, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/config',
            callback=get_config_handler,
            parameters=[
                APIParameter(
                    name='profile',
                    data_type='string',
                    required=False,
                    default='default',
                    description='Config profile (default, development, production)',
                    type=ParameterType.QUERY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Get configuration',
            description='Get jac.toml configuration content (admin only)'
        )
    );
    async def update_config_handler(
        request: Request, content: str, profile: str = "default"
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_update_config(content, profile, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/admin/config',
            callback=update_config_handler,
            parameters=[
                APIParameter(
                    name='content',
                    data_type='string',
                    required=True,
                    default=None,
                    description='TOML configuration content',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='profile',
                    data_type='string',
                    required=False,
                    default='default',
                    description='Config profile (default, development, production)',
                    type=ParameterType.QUERY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Update configuration',
            description='Update jac.toml configuration content (admin only)'
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
impl JacAPIServerAdmin.require_admin(
    Authorization: str | None
) -> TransportResponse | None {
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
    current_password: str, new_password: str, Authorization: str | None = None
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
    result = self.user_manager.update_password(
        username, current_password, new_password
    );
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
        data={'message': 'Password updated successfully', 'token': new_token},
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
    username: str, password: str, role: str = 'user', Authorization: str | None = None
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
        username=username, password=password, role=role, requires_password_reset=True
    );
    if 'error' in result {
        return TransportResponse.fail(
            code='CREATE_FAILED',
            message=result.get('error', 'User creation failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 201})
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
        result = self.user_manager.set_requires_password_reset(
            username, requires_password_reset
        );
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
        data=result, meta=Meta(extra={'http_status': 200})
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
        providers.append(
            {
                'platform': platform,
                'configured': is_configured,
                'client_id_set': bool(client_id),
                'client_secret_set': bool(platform_config.get('client_secret', ''))
            }
        );
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

"""Get configuration content (admin only)."""
impl JacAPIServerAdmin.admin_get_config(
    profile: str = "default", Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    import os;
    cwd = Path(os.getcwd());
    # Determine config file path based on profile
    if profile == "default" {
        config_path = cwd / "jac.toml";
    } else {
        config_path = cwd / f"jac.{profile}.toml";
    }
    if not config_path.exists() {
        # Return empty content if file doesn't exist
        return TransportResponse.success(
            data={
                'profile': profile,
                'content': f"# Configuration file not found: {config_path.name}\n# Create this file to configure {profile} profile.",
                'exists': False
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    try {
        content = config_path.read_text(encoding='utf-8');
        return TransportResponse.success(
            data={'profile': profile, 'content': content, 'exists': True},
            meta=Meta(extra={'http_status': 200})
        );
    } except Exception as e {
        return TransportResponse.fail(
            code='READ_ERROR',
            message=f'Failed to read config: {str(e)}',
            meta=Meta(extra={'http_status': 500})
        );
    }
}

"""Update configuration content (admin only)."""
impl JacAPIServerAdmin.admin_update_config(
    content: str, profile: str = "default", Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    import os;
    import toml;
    cwd = Path(os.getcwd());
    # Determine config file path based on profile
    if profile == "default" {
        config_path = cwd / "jac.toml";
    } else {
        config_path = cwd / f"jac.{profile}.toml";
    }
    # Validate TOML syntax before saving
    try {
        toml.loads(content);
    } except Exception as e {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message=f'Invalid TOML syntax: {str(e)}',
            meta=Meta(extra={'http_status': 400})
        );
    }
    try {
        config_path.write_text(content, encoding='utf-8');
        return TransportResponse.success(
            data={'profile': profile, 'message': 'Configuration saved successfully'},
            meta=Meta(extra={'http_status': 200})
        );
    } except Exception as e {
        return TransportResponse.fail(
            code='WRITE_ERROR',
            message=f'Failed to save config: {str(e)}',
            meta=Meta(extra={'http_status': 500})
        );
    }
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
            content={
                'error': 'Not found',
                'message': f"User '{target_username}' not found or has no graph"
            }
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
            status_code=500, content={'error': 'Internal error', 'message': str(e)}
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
            content_type = guess_result[0]
            if guess_result[0]
            else "application/octet-stream";
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
