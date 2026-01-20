# npm Publishing Guide for jac-client Packages

This guide covers how to publish and setup the jac-client npm packages (`jac-client-node` and `@jac-client/dev-deps`) for release.

## Overview

The jac-client project uses two separate npm packages to manage default dependencies:

- **`jac-client-node`**: Runtime dependencies (React, React DOM, React Router)
- **`@jac-client/dev-deps`**: Development dependencies (Vite, Babel, TypeScript, etc.)

## Prerequisites

1. **npm account**: Create an account at [npmjs.com](https://www.npmjs.com/)
2. **npm CLI**:  Ensure npm is installed (`npm --version`)
3. **Authentication**: Login to npm via CLI

   ```bash
   npm login
   ```

4. **Organization access**: You'll need access to publish under the `@jac-client` scope

## Package Structure

Each package is located in its respective directory:

```
jac-client/
└── @jac-client/
        ├── jac-client-deps/
        │   └── package.json
        └── jac-client-devDeps/
            └── package.json
```

## Creating and Publishing Process

### 1. Initialize the Package

```bash
cd jac-client/@jac-client/jac-client-deps
npm init
```

Before publishing, ensure your `package.json` has all required fields:

```json
{
  "name": "jac-client-node",
  "version": "1.0.3",
  "description": "Default dependencies for Jac-client",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/jaseci-labs/jaseci.git",
    "directory": "jac-client/jac-client-deps"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.22.0"
  }
}

```

### 2. Publish to npm

#### For jac-client-node:

```bash
cd jac-client/@jac-client/jac-client-deps
npm publish --access public
```

#### For @jac-client/dev-deps:

```bash
cd jac-client/@jac-client/jac-client-devDeps
npm publish --access public
```

> **Note**: The `--access public` flag is required for scoped packages (@jac-client/*) to be publicly available.

### 3. Verify Publication

Check that your packages are published:

```bash
npm view jac-client-node
npm view @jac-client/dev-deps
```

Or visit:

- https://www.npmjs.com/package/jac-client-node
- https://www.npmjs.com/package/@jac-client/dev-deps

## Usage in Projects

After publishing, users can install the packages in their `jac. toml`:

```toml
[dependencies.npm]
"jac-client-node" = "1.0.4"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "1.0.0"
```

## Troubleshooting

### Authentication Errors

```bash
npm logout
npm login
```

### Scope Permission Issues

Ensure you're part of the `@jac-client` organization or create the scope:

```bash
npm access public jac-client-node
```

### Version Conflicts

If version already exists:

```bash
npm version patch  # Increment version
npm publish
```

## Resources

- [npm Documentation](https://docs.npmjs.com/)
- [Semantic Versioning](https://semver.org/)
- [npm Publishing Guide](https://docs.npmjs.com/packages-and-modules/contributing-packages-to-the-registry)

## Using Published Packages

Once published, users can install the packages in their Jac client projects:

### In jac. toml

```toml
[dependencies.npm]
"jac-client-node" = "1.0.4"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "1.0.0"
```

### Direct npm Installation

```bash
npm install jac-client-node
npm install @jac-client/dev-deps
```

## Troubleshooting

### Common Issues

**Issue**: `npm ERR! 403 Forbidden`

- **Solution**: Ensure you have publish permissions for the `@jac-client` organization

  ```bash
  npm owner add <username> jac-client-node
  ```

**Issue**: `npm ERR! You do not have permission to publish`

- **Solution**: Login with correct credentials

  ```bash
  npm logout
  npm login
  ```

**Issue**: `npm ERR! You cannot publish over the previously published versions`

- **Solution**: Increment the version number in `package.json`

  ```bash
  npm version patch
  ```
