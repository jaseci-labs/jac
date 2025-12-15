# Package Management Architecture

## Overview

The Jac Client package management system abstracts npm package management into a simple `config.json` file, automatically generating `package.json` during build and install operations. This approach keeps the project root clean while maintaining full compatibility with npm tooling.

## Core Design Principles

1. **Configuration Abstraction**: Package metadata is stored in `config.json`, not directly in `package.json`
2. **Build-Time Generation**: `package.json` is dynamically generated from `config.json` when needed
3. **Minimal User Configuration**: Only essential fields (`name`, `version`, `description`, `dependencies`, `devDependencies`) are exposed to developers
4. **Automatic Defaults**: Build scripts, Babel config, and core dependencies are automatically included
5. **npm Compatibility**: Temporary root `package.json` ensures npm commands work correctly

## Architecture Components

### 1. Configuration Layer (`config.json`)

**Location**: Project root (`{project_dir}/config.json`)

**Structure**:

```json
{
  "package": {
    "name": "my-app",
    "version": "1.0.0",
    "description": "My Jac application",
    "dependencies": {
      "lodash": "^4.17.21"
    },
    "devDependencies": {
      "sass": "^1.77.8"
    }
  }
}
```

**Fields**:

- `name`: Project name (auto-populated from project filename when using `jac create_jac_app`)
- `version`: Project version (default: "1.0.0")
- `description`: Project description
- `dependencies`: Runtime npm packages (only custom packages, not React/Babel defaults)
- `devDependencies`: Development npm packages (only custom packages, not Vite/Babel defaults)

**What's NOT in config.json**:

- `scripts`: Auto-generated during build
- `babel`: Auto-generated during build
- `type`: Always `"module"`, auto-generated
- `main`: Auto-generated (default: "index.js")
- **Core dependencies (React, Vite, Babel)**: Automatically added during build time - should NOT be included in `config.json` unless you need to override the default version

### 2. Configuration Loader (`JacClientConfig`)

**File**: `jac_client/plugin/src/config_loader.jac`

**Responsibilities**:

- Load and parse `config.json`
- Merge user config with defaults
- Provide accessors for different config sections
- Validate JSON structure

**Key Methods**:

- `load()`: Loads and merges config with defaults
- `get_package_config()`: Returns the `package` section
- `get_vite_config()`: Returns the `vite` section
- `get_ts_config()`: Returns the `ts` section

**Default Package Config**:

```python
{
    'name': '',
    'version': '1.0.0',
    'description': '',
    'dependencies': {},
    'devDependencies': {}
}
```

### 3. Package.json Generator (`ViteBundler.create_package_json`)

**File**: `jac_client/plugin/src/vite_bundler.jac`

**Responsibilities**:

- Generate `package.json` from `config.json`
- Merge user dependencies with defaults
- Include build-time fields (scripts, babel, type)
- Handle project name resolution

**Generation Process**:

1. **Project Name Resolution** (in order):
   - From `config.json` `package.name`
   - From `project_name` parameter
   - From existing root `package.json` (if exists)
   - From project directory name
   - Fallback to `"jac-app"`

2. **Default Dependencies**:

   ```json
   {
     "dependencies": {
       "react": "^19.2.0",
       "react-dom": "^19.2.0",
       "react-router-dom": "^6.30.1"
     },
     "devDependencies": {
       "vite": "^6.4.1",
       "@babel/cli": "^7.28.3",
       "@babel/core": "^7.28.5",
       "@babel/preset-env": "^7.28.5",
       "@babel/preset-react": "^7.28.5"
     }
   }
   ```

3. **TypeScript Dependencies** (if TypeScript support detected):

   ```json
   {
     "devDependencies": {
       "@vitejs/plugin-react": "^4.2.1",
       "typescript": "^5.3.3",
       "@types/react": "^18.2.45",
       "@types/react-dom": "^18.2.18"
     }
   }
   ```

4. **Default Scripts**:

   ```json
   {
     "scripts": {
       "build": "npm run compile && vite build --config .jac-client.configs/vite.config.js",
       "dev": "vite dev --config .jac-client.configs/vite.config.js",
       "preview": "vite preview --config .jac-client.configs/vite.config.js",
       "compile": "babel compiled --out-dir build --extensions \".jsx,.js\" --out-file-extension .js"
     }
   }
   ```

5. **Babel Config** (always included):

   ```json
   {
     "babel": {
       "presets": [
         ["@babel/preset-env", { "modules": false }],
         "@babel/preset-react"
       ]
     }
   }
   ```

6. **Always-Included Fields**:
   - `type: "module"` (ES modules)
   - `main: "index.js"`

**Output Locations**:

- Primary: `.jac-client.configs/package.json` (persisted)
- Temporary: `{project_root}/package.json` (for npm commands, removed after install)

### 4. Package Installer (`PackageInstaller`)

**File**: `jac_client/plugin/src/package_installer.jac`

**Responsibilities**:

- Update `config.json` with new packages
- Trigger `package.json` regeneration
- Execute `npm install`
- Manage file lifecycle (move lock files, clean up root `package.json`)

**Key Methods**:

#### `install_package(package_name, version, is_dev)`

Adds a package to `config.json` and installs it:

1. Load current `config.json`
2. Add package to `dependencies` or `devDependencies`
3. Write updated `config.json`
4. Call `_regenerate_and_install()`

#### `install_all()`

Installs all packages from `config.json`:

1. Call `_regenerate_and_install()`

#### `_regenerate_and_install()`

Core installation workflow:

1. Generate `package.json` from `config.json` (via `ViteBundler.create_package_json()`)
2. Copy `package.json` to project root (npm requires it there)
3. Run `npm install` in project root
4. Move `package-lock.json` from root to `.jac-client.configs/`
5. Remove root `package.json` (keep only `.jac-client.configs/package.json`)

#### `uninstall_package(package_name, is_dev)`

Removes a package from `config.json` and uninstalls it:

1. Load current `config.json`
2. Remove package from appropriate dependencies dict
3. Write updated `config.json`
4. Call `_regenerate_and_install()` to update `package.json` and run `npm install`

#### `list_packages()`

Returns all packages from `config.json`:

```python
{
    'dependencies': {...},
    'devDependencies': {...}
}
```

## File Lifecycle

### During Package Installation

```
1. config.json (root)
   ├── User edits or CLI updates
   └── Contains: name, version, description, dependencies, devDependencies

2. ViteBundler.create_package_json()
   ├── Reads config.json
   ├── Merges with defaults
   └── Generates: .jac-client.configs/package.json

3. Copy to root
   └── package.json (root) [temporary]

4. npm install
   ├── Reads package.json (root)
   ├── Installs node_modules/
   └── Generates: package-lock.json (root)

5. Post-install cleanup
   ├── Move: package-lock.json (root) → .jac-client.configs/package-lock.json
   └── Remove: package.json (root)
```

### After Installation

**Persisted Files**:

- `config.json` (root) - Source configuration (committed to git)
- `.jac-client.configs/package.json` - Generated package.json (gitignored)
- `.jac-client.configs/package-lock.json` - Lock file (gitignored)
- `node_modules/` - Installed packages (gitignored)

**Removed Files**:

- `package.json` (root) - Removed after npm install

### During Build

```
1. Build process starts
   ├── Check for .jac-client.configs/package.json
   └── If missing, generate from config.json

2. npm run compile (Babel)
   ├── Requires package.json in root
   └── ViteBundler ensures it exists (copies from .jac-client.configs/)

3. npm run build (Vite)
   ├── Requires package.json in root
   └── ViteBundler ensures it exists

4. Build completes
   └── Root package.json may remain (for subsequent builds)
```

## CLI Integration

### Command: `jac add --cl`

**File**: `jac_client/plugin/cli.py`

**Usage**:

```bash
# Install all packages from config.json
jac add --cl

# Add specific package (dependencies)
jac add --cl lodash

# Add specific package (devDependencies)
jac add --cl -d @types/react

# Add with version
jac add --cl lodash@^4.17.21
```

**Implementation**:

1. Validates `--cl` flag is present
2. Creates `PackageInstaller` instance
3. If no package name: calls `install_all()` to install all packages from config.json
4. If package name provided:
   - Parses package name and version (handles scoped packages correctly)
   - Calls `install_package()` with `is_dev` flag
5. Handles errors and provides user feedback

**Error Handling**:

- Missing `config.json`: Suggests running `jac generate_client_config` (for legacy projects)
- npm not found: Clear error message
- npm install failure: Displays stderr

### Command: `jac remove --cl`

**File**: `jac_client/plugin/cli.py`

**Usage**:

```bash
# Remove specific package (dependencies)
jac remove --cl lodash

# Remove specific package (devDependencies)
jac remove --cl -D @types/react
```

**Implementation**:

1. Validates `--cl` flag is present
2. Validates package name is provided
3. Creates `PackageInstaller` instance
4. Calls `uninstall_package()` with `is_dev` flag
5. Handles errors and provides user feedback

**Error Handling**:

- Missing `config.json`: Suggests running `jac generate_client_config` (for legacy projects)
- Package not found: Clear error message indicating which dependency type was checked
- npm not found: Clear error message
- npm install failure: Displays stderr

### Command: `jac create_jac_app`

**File**: `jac_client/plugin/cli.py`

**Creates Initial Config**:

```json
{
  "package": {
    "name": "{project_name}",
    "version": "1.0.0",
    "description": "",
    "dependencies": {},
    "devDependencies": {}
  },
  "vite": {...},
  "ts": {...}
}
```

The `name` field is automatically populated from the project filename.

## Integration Points

### 1. Client Bundle Builder

**File**: `jac_client/plugin/client.jac`

**Integration**:

- `get_client_bundle_builder()` checks for `package.json`
- If missing, generates it via `ViteBundler.create_package_json()`
- Ensures `package.json` exists before initializing `ViteClientBundleBuilder`

### 2. Vite Bundler

**File**: `jac_client/plugin/src/vite_bundler.py`

**Integration**:

- `build()` method checks for `package.json` before building
- Calls `create_package_json()` if missing
- Ensures `node_modules` exists (runs `npm install` if needed)

### 3. Babel Processor

**File**: `jac_client/plugin/src/babel_processor.jac`

**Integration**:

- Requires `package.json` in root for `npm run compile`
- Relies on `ViteBundler` to ensure it exists

## Default Dependencies

### Runtime Dependencies (Always Included)

```json
{
  "react": "^19.2.0",
  "react-dom": "^19.2.0",
  "react-router-dom": "^6.30.1"
}
```

### Development Dependencies (Always Included)

```json
{
  "vite": "^6.4.1",
  "@babel/cli": "^7.28.3",
  "@babel/core": "^7.28.5",
  "@babel/preset-env": "^7.28.5",
  "@babel/preset-react": "^7.28.5"
}
```

### TypeScript Dependencies (Conditional)

Included only if TypeScript support is detected:

```json
{
  "@vitejs/plugin-react": "^4.2.1",
  "typescript": "^5.3.3",
  "@types/react": "^18.2.45",
  "@types/react-dom": "^18.2.18"
}
```

## Dependency Merging Strategy

When generating `package.json`, dependencies are merged as follows:

1. **Start with defaults**: Core dependencies (React, Vite, Babel)
2. **Add TypeScript deps**: If TypeScript support detected
3. **Merge user deps**: User-defined dependencies from `config.json` override defaults if same package name
4. **Preserve user deps**: Additional user packages are added

**Example**:

```json
// config.json (only custom packages)
{
  "package": {
    "dependencies": {
      "lodash": "^4.17.21"
    },
    "devDependencies": {
      "sass": "^1.77.8"
    }
  }
}

// Generated package.json (defaults + user packages)
{
  "dependencies": {
    "react": "^19.2.0",        // Auto-added default
    "react-dom": "^19.2.0",    // Auto-added default
    "react-router-dom": "^6.30.1",  // Auto-added default
    "lodash": "^4.17.21"       // User package
  },
  "devDependencies": {
    "vite": "^6.4.1",          // Auto-added default
    "@babel/cli": "^7.28.3",   // Auto-added default
    "@babel/core": "^7.28.5",  // Auto-added default
    "@babel/preset-env": "^7.28.5",  // Auto-added default
    "@babel/preset-react": "^7.28.5",  // Auto-added default
    "sass": "^1.77.8"          // User package
  }
}
```

> **Note**: React, Babel, and Vite packages are automatically added during build time. Users should only include custom packages in `config.json`. If a user explicitly adds a default package (e.g., `react`), it will override the default version.

## Error Scenarios and Handling

### Missing config.json

**Scenario**: User runs `jac add --cl` without `config.json`

**Handling**:

- `PackageInstaller` raises `ClientBundleError`
- Error message: `"config.json not found. Run 'jac generate_client_config' first."` (for legacy projects)
- For new projects: `config.json` is automatically created with `jac create_jac_app`

### npm Not Found

**Scenario**: `npm` command not available in PATH

**Handling**:

- `subprocess.run()` raises `FileNotFoundError`
- `PackageInstaller` catches and raises `ClientBundleError`
- Error message: `"npm command not found. Ensure Node.js and npm are installed."`

### npm Install Failure

**Scenario**: `npm install` fails (network, permissions, etc.)

**Handling**:

- `subprocess.run()` raises `CalledProcessError`
- `PackageInstaller` catches and raises `ClientBundleError`
- Error message includes `e.stderr` for debugging

### Missing package.json During Build

**Scenario**: Build process starts but `package.json` doesn't exist

**Handling**:

- `client.jac.get_client_bundle_builder()` checks for existence
- If missing, calls `ViteBundler.create_package_json()` automatically
- Ensures build can proceed without manual intervention

## Benefits of This Architecture

1. **Clean Project Root**: No `package.json` clutter in project root
2. **Version Control Friendly**: Only `config.json` needs to be committed
3. **Simplified Configuration**: Developers only manage essential package info
4. **Automatic Defaults**: Build tools and scripts are automatically configured
5. **npm Compatibility**: Temporary root `package.json` ensures npm commands work correctly
6. **Consistent Builds**: Generated `package.json` ensures consistent build environment
7. **Easy Package Management**: Simple CLI commands for adding/removing packages
8. **Type Safety**: Configuration structure is validated and typed

## Future Enhancements

Potential improvements to the package management system:

1. **Package Version Management**: CLI commands to update/check package versions
2. **Dependency Audit**: Integration with `npm audit` for security checks
3. **Lock File Management**: Better handling of `package-lock.json` updates
4. **Workspace Support**: Multi-package workspace configuration
5. **Custom Scripts**: Allow user-defined scripts in `config.json` (merged with defaults)
6. **Package Groups**: Organize dependencies into logical groups
7. **Auto-update**: Automatic updates for patch/minor versions
