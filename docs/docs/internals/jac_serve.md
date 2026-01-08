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

**Core Implementation**: Returns a `JacHTTPServer` instance (wraps Python's `HTTPServer`).

**Plugin Override**: Plugins can return their own server implementation (e.g., FastAPIServer).

**Signature**:
```python
def get_server(
    handler_class: type[BaseHTTPRequestHandler],
    port: int = 8000,
) -> Server:  # Returns Server instance (JacHTTPServer, FastAPIServer, etc.)
```

**Core Behavior**:
- Creates and returns a `JacHTTPServer` instance
- Wraps Python's `HTTPServer` with `Server` interface
- Uses provided `handler_class` for request handling
- Binds to `0.0.0.0:port`

**Plugin Override Example** (jac-scale):
- Returns a `FastAPIServer` instance
- Implements the `Server` abstract class
- Provides async support and OpenAPI documentation

**Usage**:
```python
# In core
handler_class = api_server.create_handler()
server = Jac.get_server(handler_class, port=8000)
# Returns: JacHTTPServer instance

# In jac-scale plugin
server = Jac.get_server(handler_class, port=8000)
# Returns: FastAPIServer instance
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

### 3. `getExecutionManagement()`

**Purpose**: Returns the execution management component responsible for executing walkers and functions.

**Core Implementation**: Returns an `ExecutionManager` instance that handles:
- Function execution in user contexts
- Walker spawning in user contexts
- Context management and report collection

**Plugin Override**: Plugins can return custom execution management implementations with:
- Custom execution strategies
- Enhanced error handling
- Performance optimizations

**Signature**:
```python
def get_execution_management(
    session_path: str,
    user_manager: UserManager
) -> ExecutionManager:  # Returns ExecutionManager or compatible instance
```

**Core Behavior**:
- Creates `ExecutionManager` with user manager dependency
- Executes functions in user's root context
- Spawns walkers on user's root or specified nodes
- Returns serialized results with reports

**Plugin Override Example** (jac-scale):
- Returns enhanced `ExecutionManager` with:
  - Async execution support
  - Custom context management
  - Enhanced error reporting

**Usage**:
```python
# In core
user_manager = Jac.get_user_management(session_path=".session")
execution_manager = Jac.get_execution_management(".session", user_manager)
# Returns: ExecutionManager instance

# In jac-scale plugin
execution_manager = Jac.get_execution_management(".session", user_manager)
# Returns: Enhanced ExecutionManager instance
```

---

### 4. `registerEndpoints()`

**Purpose**: Registers endpoint definitions with the server framework.

**Core Implementation**: No-op - endpoints are handled via route matching in the request handler.

**Plugin Override**: Plugins can convert `EndpointDefinition` objects to framework-specific routes.

**Signature**:
```python
def register_endpoints(
    endpoint_definitions: list[EndpointDefinition],
    api_server: JacAPIServer
) -> None:
```

**Core Behavior**:
- No-op in core (endpoints handled via route mapping in handler)
- Endpoints are matched using `_route_mapping` dictionary

**Plugin Override Example** (jac-scale):
- Converts `EndpointDefinition` to `JEndPoint` objects
- Registers routes with FastAPI app
- Sets up request/response models

---

### 5. `registerDocsEndpoint()`

**Purpose**: Registers the `/docs` endpoint for API documentation.

**Core Implementation**: No-op - `/docs` is handled via route matching in request handler (returns simple HTML).

**Plugin Override**: Plugins can register Swagger/OpenAPI documentation endpoints.

**Signature**:
```python
def register_docs_endpoint(
    api_server: JacAPIServer
) -> None:
```

**Core Behavior**:
- No-op in core
- `/docs` endpoint returns simple HTML listing of endpoints

**Plugin Override Example** (jac-scale):
- FastAPI automatically provides `/docs` for Swagger UI
- Can customize OpenAPI schema

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
- Calls `map_walkers_to_endpoints()` to create route mapping dictionary
- Creates `EndpointDefinition` objects from walkers and functions
- Calls `register_endpoints()` hook (no-op in core)
- Calls `register_docs_endpoint()` hook (no-op in core)
- Marks endpoints as built

**Plugin Override** (jac-scale):
- Converts `EndpointDefinition` to `JEndPoint` objects in `register_endpoints()` hook
- Registers routes with FastAPI app
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

### Core Server (jaclang/runtimelib/server.jac)

All server components are defined in a single file `server.jac`:
- Type definitions (Response, UserData, JsonValue, StatusCode)
- Core objects (UserManager, ExecutionManager, ModuleIntrospector, etc.)
- Server abstractions (Server abstract class, JacHTTPServer)
- Main orchestrator (JacAPIServer)

1. **User Management**: Created in `JacAPIServer.postinit()` via hook
   ```python
   self.user_manager = Jac.get_user_management(self.session_path);
   ```

2. **Execution Management**: Created in `JacAPIServer.postinit()` via hook
   ```python
   self.execution_manager = Jac.get_execution_management(
       self.session_path, self.user_manager
   );
   ```

3. **Endpoint Building**: `build_endpoints()` creates `EndpointDefinition` objects and calls `register_endpoints()` hook

4. **Route Mapping**: `map_walkers_to_endpoints()` creates fast lookup dictionary for O(1) route matching

5. **Server Instance**: Created in `JacAPIServer.start()` via hook
   ```python
   handler_class = self.create_handler();
   server_instance = Jac.get_server(handler_class, self.port);
   server_instance.start(self.port);
   ```

6. **Response Handling**: Uses `ResponseBuilder` static methods throughout request handlers

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
  - ✅ Returns `JacHTTPServer` (implements `Server` abstract class)
  - ✅ Signature: `get_server(handler_class, port) -> Server`
  - ✅ Allow plugins to return their own server instance (FastAPIServer, etc.)
- Extract `getUserManagement()` from `JacAPIServer.postinit()`
  - ✅ Moved UserManager creation to `get_user_management()` hook
  - ✅ Signature: `get_user_management(session_path) -> UserManager`
  - ✅ Allow plugins to return enhanced user managers (JWT, SSO, DB-backed)
- Extract `getExecutionManagement()` from `JacAPIServer.postinit()`
  - ✅ Moved ExecutionManager creation to `get_execution_management()` hook
  - ✅ Signature: `get_execution_management(session_path, user_manager) -> ExecutionManager`
  - ✅ Allow plugins to return custom execution managers
- Create hook specifications in `JacAPIServer` class
  - ✅ Added hooks to `JacAPIServer` class in `runtime.py`
  - ✅ Hooks automatically registered via `generate_plugin_helpers`
- Add `registerEndpoints()` hook
  - ✅ Added `register_endpoints()` hook for plugin endpoint registration
  - ✅ Core implementation: No-op (endpoints handled via route mapping)
- Add `registerDocsEndpoint()` hook
  - ✅ Added `register_docs_endpoint()` hook for documentation endpoints
  - ✅ Core implementation: No-op (simple HTML in handler)
- Update `start()` and `postinit()` to use hooks
  - ✅ Updated `postinit()` to call hooks for user/execution management
  - ✅ Updated `start()` to call `get_server()` hook
  - ✅ Updated `build_endpoints()` to call `register_endpoints()` hook
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

1. **Server** (Abstract Base Class)
   - Abstract interface: `start()`, `stop()`, `get_instance()`
   - All server implementations must extend this

2. **JacHTTPServer** (Core)
   - Implements `Server` abstract class
   - Wraps Python's built-in `http.server.HTTPServer`
   - Synchronous request handling
   - Simple and lightweight

3. **FastAPIServer** (jac-scale)
   - Implements `Server` abstract class
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

