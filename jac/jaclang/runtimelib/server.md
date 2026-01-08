# Server Plugin Architecture

## Overview

The Jac API Server component is designed with a plugin architecture that allows plugins (like `jac-scale`) to override core server implementations. This enables different server frameworks (e.g., FastAPI, Flask) to be used while maintaining a consistent interface.

## Architecture Principles

1. **Abstract Base Interface**: Core defines abstract methods that plugins can implement
2. **Plugin Hooks**: Plugins use `@hookimpl` to override server behavior
3. **Default Implementation**: Core provides a default HTTPServer implementation
4. **Extensibility**: Plugins can override specific components without replacing the entire server

## Plugin Hooks

### 1. `getServer()`

**Purpose**: Returns the server instance that will handle HTTP requests.

**Core Implementation**: Returns an `HTTPServer` instance from Python's `http.server` module.

**Plugin Override**: Plugins can return their own server implementation (e.g., FastAPI app).

**Signature**:
```python
def get_server(
    module_name: str,
    session_path: str,
    port: int = 8000,
    base_path: str | None = None
) -> Any:  # Returns server instance (HTTPServer, FastAPI app, etc.)
```

**Core Behavior**:
- Creates and returns an `HTTPServer` instance
- Uses `BaseHTTPRequestHandler` for request handling
- Binds to `0.0.0.0:port`

**Plugin Override Example** (jac-scale):
- Returns a `FastAPI` application instance
- Uses `JFastApiServer` for endpoint registration
- Provides async support and OpenAPI documentation

**Usage**:
```python
# In core
server = get_server(module_name="myapp", session_path=".session", port=8000)
# Returns: HTTPServer instance

# In jac-scale plugin
server = get_server(module_name="myapp", session_path=".session", port=8000)
# Returns: FastAPI app instance
```

---

### 2. `getUserManagement()`

**Purpose**: Returns the user management component responsible for authentication and user data.

**Core Implementation**: Returns a `UserManager` instance that handles:
- User creation and authentication
- Token validation
- User data persistence (JSON file-based)

**Plugin Override**: Plugins can return custom user management implementations with:
- Database-backed storage (MongoDB, Redis, etc.)
- JWT token support
- SSO integration
- Custom authentication mechanisms

**Signature**:
```python
def get_user_management(
    session_path: str
) -> UserManager:  # Returns UserManager or compatible instance
```

**Core Behavior**:
- Creates `UserManager` with JSON file persistence
- Supports username/password authentication
- Generates simple tokens for session management
- Stores user data in `{session_path}.users.json`

**Plugin Override Example** (jac-scale):
- Returns enhanced `UserManager` with:
  - JWT token generation and validation
  - SSO support (Google, etc.)
  - Database integration options
  - Token refresh mechanisms

**Usage**:
```python
# In core
user_manager = get_user_management(session_path=".session")
# Returns: UserManager with JSON file storage

# In jac-scale plugin
user_manager = get_user_management(session_path=".session")
# Returns: Enhanced UserManager with JWT/SSO support
```

---

### 3. `handleResponse()` (Optional)

**Purpose**: Handles HTTP response formatting and sending.

**Core Implementation**: Uses `ResponseBuilder` static methods to send responses via `BaseHTTPRequestHandler`.

**Plugin Override**: Plugins can customize response handling for their server framework.

**Signature**:
```python
def handle_response(
    handler: Any,  # Request handler (BaseHTTPRequestHandler, Request, etc.)
    response: Response,  # Response object with status, body, content_type
) -> None:
```

**Core Behavior**:
- Uses `ResponseBuilder.send_json()` for JSON responses
- Uses `ResponseBuilder.send_html()` for HTML responses
- Adds CORS headers automatically
- Adds custom headers from config

**Plugin Override Example** (jac-scale):
- Uses FastAPI's `JSONResponse` and `HTMLResponse`
- Supports async response handling
- Custom middleware integration

**Note**: This hook may not be necessary if response handling is tightly coupled with the server framework. Consider if this abstraction is needed.

---

## Implementation Strategy

### Core (jaclang/runtimelib/server)

1. **Define Hook Specifications**: Create a `JacAPIServer` class with hook methods
2. **Default Implementation**: Implement default behavior using HTTPServer
3. **Hook Registration**: Register hooks with `plugin_manager`

### Plugin (jac-scale)

1. **Implement Hooks**: Use `@hookimpl` to override hook methods
2. **Custom Server**: Return FastAPI app from `get_server()`
3. **Enhanced Features**: Extend user management with JWT/SSO

## Hook Registration Pattern

```python
# In core: Define hook spec
class JacAPIServer:
    @hookspec
    def get_server(...) -> Any:
        """Get server instance."""
        pass
    
    @hookspec
    def get_user_management(...) -> UserManager:
        """Get user management instance."""
        pass

# In plugin: Implement hook
class JacScalePlugin:
    @hookimpl
    def get_server(...) -> FastAPI:
        """Return FastAPI server."""
        # Implementation
        pass
    
    @hookimpl
    def get_user_management(...) -> EnhancedUserManager:
        """Return enhanced user manager."""
        # Implementation
        pass
```

## Server Lifecycle

The server follows a three-phase lifecycle:

### Phase 1: Build Endpoints (Compile Time)
**Method**: `build_endpoints()`

Converts walkers and functions to endpoint definitions at compile time. This allows:
- Early validation of endpoint configurations
- Static analysis of API structure
- Pre-generation of API documentation

**Core Implementation**: 
- Loads module introspector
- Marks endpoints as built
- Actual route registration happens in handler creation

**Plugin Override** (jac-scale):
- Converts walkers/functions to `JEndPoint` objects
- Stores endpoints for later registration
- Validates endpoint configurations

### Phase 2: Apply Configurations
**Method**: `apply_config()`

Applies server-specific configurations before starting:
- CORS settings
- Security headers
- Route prefixes
- Base route apps
- Middleware configuration

**Core Implementation**: 
- Configurations are read from `jac.toml` during `start()`
- No additional configuration needed for basic HTTPServer

**Plugin Override** (jac-scale):
- Applies FastAPI middleware (CORS, etc.)
- Configures OpenAPI security schemes
- Sets up SSO providers

### Phase 3: Start Server (Runtime)
**Method**: `start()`

Starts the server with pre-built endpoints and configurations.

**Flow**:
1. Check if endpoints are built → call `build_endpoints()` if not
2. Apply configurations → call `apply_config()`
3. Start the server → create handler/server instance and serve

**Core Implementation**: 
- Creates `HTTPServer` with request handler
- Handler routes requests based on path
- Serves on `0.0.0.0:port`

**Plugin Override** (jac-scale):
- Registers all pre-built endpoints with FastAPI
- Configures OpenAPI documentation
- Starts FastAPI server with uvicorn

## Current Implementation

### Core Server (jaclang/runtimelib/server)

1. **User Management**: Created in `JacAPIServer.postinit()` (line 686)
   ```python
   self.user_manager = UserManager(session_path=self.session_path);
   ```

2. **Endpoint Building**: `build_endpoints()` loads introspector and marks endpoints as built

3. **Server Instance**: Created in `JacAPIServer.start()` (line 1146)
   ```python
   with HTTPServer(('0.0.0.0', self.port), handler_class) as httpd:
       httpd.serve_forever();
   ```

4. **Response Handling**: Uses `ResponseBuilder` static methods throughout request handlers

### Plugin Override (jac-scale)

Currently, jac-scale extends `JacAPIServer` via class inheritance:
- Overrides `build_endpoints()` to create `JEndPoint` objects from walkers/functions
- Overrides `apply_config()` to configure FastAPI middleware and OpenAPI
- Overrides `start()` to register endpoints and start FastAPI server
- Extends user management with JWT/SSO support
- Uses FastAPI's response types

## Migration Path

### Phase 1: Documentation (Current) ✅
- Document the plugin architecture
- Define hook interfaces
- Specify expected behaviors

### Phase 2: Hook Extraction ✅
- Extract `getServer()` method from `JacAPIServer.start()`
  - ✅ Moved HTTPServer creation logic to `get_server()` hook
  - ✅ Current: `HTTPServer(('0.0.0.0', self.port), handler_class)` in `start()`
  - ✅ Target: `get_server()` hook that returns server instance
  - ✅ Allow plugins to return their own server instance (FastAPI, Flask, etc.)
- Extract `getUserManagement()` from `JacAPIServer.postinit()`
  - ✅ Moved UserManager creation to `get_user_management()` hook
  - ✅ Current: `UserManager(session_path=self.session_path)` in `postinit()`
  - ✅ Target: `get_user_management()` hook that returns UserManager instance
  - ✅ Allow plugins to return enhanced user managers (JWT, SSO, DB-backed)
- Create hook specifications in `JacAPIServer` class
  - ✅ Added `get_server()` and `get_user_management()` static methods to `JacAPIServer` in `runtime.py`
  - ✅ Hooks automatically registered via `generate_plugin_helpers`
- Update `start()` and `postinit()` to use hooks
  - ✅ Updated `postinit()` to call `Jac.get_user_management()`
  - ✅ Updated `start()` to call `Jac.get_server()`
  - ✅ Fallback to default implementation if no plugin registered

### Phase 3: Plugin Implementation
- Update jac-scale to use hooks instead of class inheritance
- Test plugin override behavior
- Ensure backward compatibility

### Phase 4: Refinement
- Add `handleResponse()` hook if needed
- Optimize hook signatures
- Add additional hooks as required

## Key Components

### Server Types

1. **HTTPServer** (Core)
   - Python's built-in `http.server.HTTPServer`
   - Synchronous request handling
   - Simple and lightweight

2. **FastAPI** (jac-scale)
   - Modern async web framework
   - Automatic OpenAPI documentation
   - Type validation with Pydantic

### User Management Types

1. **UserManager** (Core)
   - JSON file-based storage
   - Simple token-based auth
   - Basic user CRUD operations

2. **Enhanced UserManager** (jac-scale)
   - JWT token support
   - SSO integration
   - Database backends (MongoDB, Redis)
   - Token refresh mechanisms

## Example: Plugin Implementation

```python
# jac-scale/jac_scale/plugin.jac
class JacScaleServerPlugin:
    @hookimpl
    def get_server(
        module_name: str,
        session_path: str,
        port: int = 8000,
        base_path: str | None = None
    ) -> FastAPI:
        """Return FastAPI server instance."""
        server = JacAPIServer(
            module_name=module_name,
            session_path=session_path,
            port=port,
            base_path=base_path
        )
        return server.get_app()  # Returns FastAPI app
    
    @hookimpl
    def get_user_management(session_path: str) -> UserManager:
        """Return enhanced user manager with JWT support."""
        return EnhancedUserManager(session_path=session_path)
```

## Benefits

1. **Flexibility**: Plugins can use any server framework
2. **Extensibility**: Easy to add new features without modifying core
3. **Maintainability**: Clear separation between core and plugin code
4. **Testability**: Can mock server implementations for testing
5. **Backward Compatibility**: Core continues to work without plugins

## Future Considerations

1. **Additional Hooks**: Consider hooks for:
   - Route registration
   - Middleware configuration
   - Error handling
   - Request preprocessing

2. **Hook Priority**: Support for hook ordering/priority if multiple plugins exist

3. **Configuration**: Hook for server configuration management

4. **Lifecycle Hooks**: Startup/shutdown hooks for server lifecycle management

