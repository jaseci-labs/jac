# Custom Configuration

Customize your Jac Client build process through a simple JSON-based configuration system.

## Overview

The Jac Client uses a **JSON-based configuration system** that allows you to customize the Vite build process, add plugins, and override build options without manually editing generated configuration files. All customizations are made through a `config.json` file in your project root.

## Quick Start

### Config File Creation

When you create a new Jac Client project using `jac create_jac_app`, a `config.json` file is automatically created with the proper structure:

```json
{
  "vite": {
    "plugins": [],
    "lib_imports": [],
    "build": {},
    "server": {},
    "resolve": {}
  },
  "ts": {},
  "package": {
    "name": "",
    "version": "1.0.0",
    "description": "",
    "dependencies": {},
    "devDependencies": {}
  }
}
```

### Basic Example: Adding Tailwind CSS

```json
{
  "vite": {
    "plugins": [
      "tailwindcss()"
    ],
    "lib_imports": [
      "import tailwindcss from '@tailwindcss/vite'"
    ]
  }
}
```

## Configuration Structure

### Top-Level Keys

- **`vite`**: Vite-specific configuration (plugins, build options, server, resolve)
- **`ts`**: TypeScript configuration (reserved for future use)
- **`package`**: npm package configuration (dependencies, devDependencies, scripts)

> **Note**: For package management, see [Package Management](./package-management.md) for detailed documentation on managing dependencies.

### Vite Configuration Keys

#### `plugins` (Array of Strings)

Add Vite plugins by providing function calls as strings. These are directly injected into the generated `vite.config.js`.

**Format**: Array of plugin function call strings

**Examples**:

```json
{
  "vite": {
    "plugins": [
      "tailwindcss()",
      "react()",
      "myPlugin({ option: 'value' })"
    ]
  }
}
```

**Note**: Plugin function calls are injected as-is. For complex options, use JavaScript object syntax in the string.

#### `lib_imports` (Array of Strings)

Import statements required for the plugins. These are added to the top of the generated `vite.config.js`.

**Format**: Array of import statement strings

**Examples**:

```json
{
  "vite": {
    "lib_imports": [
      "import tailwindcss from '@tailwindcss/vite'",
      "import react from '@vitejs/plugin-react'",
      "import myPlugin from 'my-vite-plugin'"
    ]
  }
}
```

**Note**: Each plugin in `plugins` should have a corresponding import in `lib_imports`.

#### `build` (Object)

Override Vite build options. This object is merged with the default build configuration.

**Format**: JavaScript object (will be converted to JS in generated config)

**Common Options**:

- `sourcemap`: Enable source maps (`true` | `false` | `"inline"` | `"hidden"`)
- `minify`: Minification method (`"esbuild"` | `"terser"` | `false`)
- `rollupOptions`: Rollup-specific options
- `outDir`: Output directory (default: `compiled/dist/assets`)
- `emptyOutDir`: Clear output directory before build

**Example**:

```json
{
  "vite": {
    "build": {
      "sourcemap": true,
      "minify": "esbuild",
      "rollupOptions": {
        "output": {
          "manualChunks": {
            "vendor": ["react", "react-dom"]
          }
        }
      }
    }
  }
}
```

#### `server` (Object)

Configure the Vite development server.

**Format**: JavaScript object

**Common Options**:

- `port`: Server port (default: `5173`)
- `open`: Open browser automatically (`true` | `false`)
- `host`: Server host (`true` | `"0.0.0.0"` | specific host)
- `cors`: Enable CORS (`true` | `false`)

**Example**:

```json
{
  "vite": {
    "server": {
      "port": 3000,
      "open": true,
      "host": "0.0.0.0"
    }
  }
}
```

#### `resolve` (Object)

Override module resolution options.

**Format**: JavaScript object

**Common Options**:

- `alias`: Path aliases (object mapping aliases to paths)
- `extensions`: File extensions to resolve (array of strings)
- `dedupe`: Deduplicate packages (array of package names)

**Example**:

```json
{
  "vite": {
    "resolve": {
      "alias": {
        "@components": "./src/components",
        "@utils": "./src/utils"
      },
      "dedupe": ["react", "react-dom"]
    }
  }
}
```

**Note**: The default configuration already includes:

- `@jac-client/utils` → `compiled/client_runtime.js`
- `@jac-client/assets` → `compiled/assets`
- Extensions: `[".mjs", ".js", ".mts", ".ts", ".jsx", ".tsx", ".json"]`

### Package Configuration (`package`)

Manage npm dependencies and package metadata. This section is used to generate `package.json`.

**Format**: JavaScript object

**Keys**:

- `name`: Package name
- `version`: Package version
- `description`: Package description
- `dependencies`: Runtime dependencies (object mapping package names to versions)
- `devDependencies`: Development dependencies (object mapping package names to versions)
- `scripts`: npm scripts (optional)

**Example**:

```json
{
  "package": {
    "name": "my-jac-app",
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

> **Important**: React, React-DOM, React-Router-DOM, Vite, and Babel packages are **automatically added during build time** and should not be included in `config.json`. Only add custom packages that aren't part of the defaults.

**Note**: It's recommended to use the CLI commands (`jac add --cl` and `jac remove --cl`) to manage packages rather than manually editing this section. See [Package Management](./package-management.md) for details.

## How It Works

### Configuration Loading

1. **Automatic Creation**: When you create a new project with `jac create_jac_app`, `config.json` is automatically created in the project root.

2. **Default Configuration**: The system starts with default settings that include:
   - Base Vite configuration
   - Required aliases (`@jac-client/utils`, `@jac-client/assets`)
   - TypeScript extensions (if TypeScript is enabled)
   - React plugin (if TypeScript is enabled)
   - Package configuration structure

3. **User Configuration**: Your `config.json` is loaded and merged with defaults using deep merge.

4. **Config Generation**: The merged configuration is used to generate `vite.config.js` in `.jac-client.configs/` directory.

5. **Build Execution**: Vite uses the generated config file for bundling.

### Configuration Workflow

```
1. Developer edits config.json in project root
   ↓
2. Build process loads config.json via JacClientConfig
   ↓
3. Config merged with defaults (deep merge)
   ↓
4. ViteBundler generates vite.config.js in .jac-client.configs/
   ↓
5. Vite uses generated config for bundling
   ↓
6. Generated config is gitignored (config.json is committed)
```

### Generated Config Location

The generated `vite.config.js` is created in `.jac-client.configs/vite.config.js`. This directory is automatically added to `.gitignore`, so you don't commit generated files. Only `config.json` should be committed to version control.

## Examples

### Example 1: Tailwind CSS

```json
{
  "vite": {
    "plugins": [
      "tailwindcss()"
    ],
    "lib_imports": [
      "import tailwindcss from '@tailwindcss/vite'"
    ]
  }
}
```

**Required package.json dependencies**:

```json
{
  "dependencies": {
    "@tailwindcss/vite": "^4.1.17",
    "tailwindcss": "^4.1.17"
  }
}
```

### Example 2: Multiple Plugins

```json
{
  "vite": {
    "plugins": [
      "react()",
      "tailwindcss()",
      "myCustomPlugin({ option: 'value' })"
    ],
    "lib_imports": [
      "import react from '@vitejs/plugin-react'",
      "import tailwindcss from '@tailwindcss/vite'",
      "import myCustomPlugin from 'my-vite-plugin'"
    ]
  }
}
```

### Example 3: Custom Build Options

```json
{
  "vite": {
    "build": {
      "sourcemap": true,
      "minify": "esbuild",
      "rollupOptions": {
        "output": {
          "manualChunks": {
            "react-vendor": ["react", "react-dom"],
            "router": ["react-router-dom"]
          }
        }
      }
    }
  }
}
```

### Example 4: Development Server Configuration

```json
{
  "vite": {
    "server": {
      "port": 3000,
      "open": true,
      "host": "0.0.0.0",
      "cors": true
    }
  }
}
```

### Example 5: Custom Path Aliases

```json
{
  "vite": {
    "resolve": {
      "alias": {
        "@components": "./src/components",
        "@utils": "./src/utils",
        "@styles": "./src/styles"
      }
    }
  }
}
```

**Note**: When using custom aliases, you'll need to use relative paths in the config since `path.resolve()` is handled in the generated config. The system automatically resolves paths relative to the project root.

## Best Practices

### 1. Only Override What You Need

The default configuration handles most use cases. Only add customizations when necessary:

```json
{
  "vite": {
    "plugins": [
      "tailwindcss()"
    ],
    "lib_imports": [
      "import tailwindcss from '@tailwindcss/vite'"
    ]
  }
}
```

 **Good**: Only adds Tailwind plugin
 **Bad**: Copying entire default config unnecessarily

### 2. Keep Plugins and Imports in Sync

For each plugin in `plugins`, ensure there's a corresponding import in `lib_imports`:

```json
{
  "vite": {
    "plugins": ["myPlugin()"],
    "lib_imports": ["import myPlugin from 'my-plugin'"]
  }
}
```

### 3. Use Object Format for Complex Options

For `build`, `server`, and `resolve`, use object format:

```json
{
  "vite": {
    "build": {
      "sourcemap": true
    }
  }
}
```

 **Good**: Object format
 **Bad**: String format for these keys

### 4. Version Control

- **Commit**: `config.json` (your customizations)
- **Don't commit**: `.jac-client.configs/` (generated files)

The `.gitignore` automatically excludes generated configs.

### 5. Test After Changes

After modifying `config.json`, test your build:

```bash
npm run build
```

## CLI Command

### Generate Default Config (Legacy Projects)

> **Note**: For projects created with Jac Client 0.2.4 or later, `config.json` is automatically created when you run `jac create_jac_app`. This command is only needed for projects created before version 0.2.4.

Create a default `config.json` file for legacy projects:

```bash
jac generate_client_config
```

**Behavior**:

- Creates `config.json` if it doesn't exist
- Fails if `config.json` already exists (prevents overwriting)
- Provides helpful output with examples

**When to use**:

- Migrating projects created before Jac Client 0.2.4
- Manually setting up configuration in an existing project

## Troubleshooting

### Config File Not Found

**Problem**: `config.json` doesn't exist in your project.

**Solution**:

- For new projects: `config.json` is automatically created with `jac create_jac_app`
- For legacy projects (pre-0.2.4): Run `jac generate_client_config` to create it
- Ensure you're in the project root directory

### Config Not Applied

**Problem**: Changes to `config.json` aren't reflected in the build.

**Solution**:

- Ensure `config.json` is in the project root
- Check JSON syntax is valid
- Verify the build process regenerates the config (it should automatically)

### Plugin Not Working

**Problem**: Plugin is added but not working.

**Solution**:

- Verify the plugin is installed in `package.json`
- Check that the import statement matches the plugin package name
- Ensure the plugin function call syntax is correct
- Check the generated `vite.config.js` in `.jac-client.configs/` to see if it was injected correctly

### Build Options Not Applied

**Problem**: Build options in `config.json` aren't being used.

**Solution**:

- Ensure options are in object format (not strings)
- Check that the option names match Vite's API
- Verify the generated config in `.jac-client.configs/vite.config.js`

### JSON Syntax Errors

**Problem**: Invalid JSON in `config.json`.

**Solution**:

- Use a JSON validator
- Check for trailing commas
- Ensure all strings are properly quoted
- Verify object/array brackets are balanced

## Advanced Usage

### Conditional Configuration

You can structure your config to work with different environments by using comments (though JSON doesn't support comments, you can use a build script to process the config):

```json
{
  "vite": {
    "build": {
      "sourcemap": true
    },
    "server": {
      "port": 3000
    }
  }
}
```

### Merging with Defaults

The system uses deep merge, so you only need to specify the keys you want to override:

```json
{
  "vite": {
    "build": {
      "sourcemap": true
    }
  }
}
```

This merges with defaults, so other build options remain unchanged.

## Related Documentation

- [Package Management](./package-management.md) - Manage npm dependencies through config.json
- [Architecture Overview](../../../architecture.md) - Detailed system architecture
- [Tailwind CSS](../styling/tailwind.md) - Example of using config.json for Tailwind
- [Vite Documentation](https://vitejs.dev/config/) - Full Vite configuration reference
