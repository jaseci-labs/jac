# Jac-Client: npm → Bun Migration Analysis

This document provides a comprehensive analysis of migrating jac-client from npm to Bun, including code that can be removed, simplified, and what needs to be replaced.

## Executive Summary

| Metric | Current (npm) | After Bun Migration |
|--------|---------------|---------------------|
| Package manager commands | npm install, npx | bun install, bun x |
| Transpilation | Babel (5 packages) | Bun native (0 packages) |
| Lock file | package-lock.json | bun.lockb |
| Node version management | NVM integration | Not needed (Bun self-contained) |
| Dev dependencies | 8 packages | 4 packages (estimated) |
| Estimated LoC removable | ~500 lines | - |

---

## 1. Code That Can Be Completely Removed

### 1.1 Babel-Related Code (~150 lines removable)

Bun has native JSX/TSX transpilation, so all Babel processing code can be removed.

**Files to delete:**

- `jac_client/plugin/src/babel_processor.jac` (entire file)
- `jac_client/plugin/src/impl/babel_processor.impl.jac` (entire file ~90 lines)

**Code to remove from `vite_bundler.impl.jac`:**

```jac
# Lines 47-52 - Babel scripts in package.json
scripts = {
    'build': 'npm run compile && vite build --config ...',  # Remove 'npm run compile &&'
    'compile': 'babel compiled --out-dir build ...'          # Remove entirely
};

# Lines 55-57 - Babel config in package.json
babel_config = {
    'presets': [['@babel/preset-env', {'modules': False}], '@babel/preset-react']
};

# Line 67 - Remove 'babel': babel_config from package_data
```

**Dev dependencies to remove (from `@jac-client/jac-client-devDeps/package.json`):**

```json
{
  "@babel/cli": "^7.28.3",        // REMOVE
  "@babel/core": "^7.28.5",       // REMOVE
  "@babel/preset-env": "^7.28.5", // REMOVE
  "@babel/preset-react": "^7.28.5" // REMOVE
}
```

### 1.2 NVM/Node Version Management (~200 lines removable)

Bun is self-contained and doesn't need Node.js version management.

**Files to delete:**

- `jac_client/plugin/utils/node_installer.jac` (entire file)
- `jac_client/plugin/utils/impl/node_installer.impl.jac` (entire file ~240 lines)

**Code to remove from test files:**

`conftest.py` - Remove NVM path detection (~15 lines):

```python
# Lines 86-96
def _get_env_with_npm() -> dict[str, str]:
    """Get environment dict with npm in PATH."""
    # ... entire function can be simplified or removed
```

`test_helpers.py` - Remove NVM detection (~20 lines):

```python
# Lines 29-49
def get_env_with_npm() -> dict[str, str]:
    # ... NVM-specific code not needed
```

### 1.3 package-lock.json Handling (~30 lines removable)

**Code to remove from `vite_bundler.impl.jac`:**

```jac
# Lines 138-154 - _cleanup_root_package_files
# Lines for moving package-lock.json can be removed/simplified

# Lines 461-468 - package-lock.json cleanup in build()
build_package_lock = build_dir / 'package-lock.json';
if build_package_lock.exists() { ... }
```

---

## 2. Code That Needs Replacement

### 2.1 Package Installation Commands

**File: `package_installer.impl.jac` (Lines 48-65)**

Current:

```jac
result = subprocess.run(
    ['npm', 'install', '--progress'],
    cwd=self.project_dir,
    ...
);
print("\n  ⏳ Installing npm packages...\n", flush=True);
print("\n  ✔ npm packages installed", flush=True);
raise ClientBundleError('npm command not found. Ensure Node.js and npm are installed.')
```

Replace with:

```jac
result = subprocess.run(
    ['bun', 'install'],
    cwd=self.project_dir,
    ...
);
print("\n  ⏳ Installing packages...\n", flush=True);
print("\n  ✔ Packages installed", flush=True);
raise ClientBundleError('bun command not found. Install Bun: https://bun.sh')
```

### 2.2 Build Commands in `vite_bundler.impl.jac`

**Lines 403-410 - npm install:**

```jac
# Current
result = subprocess.run(['npm', 'install', '--progress'], cwd=build_dir, ...)

# Replace with
result = subprocess.run(['bun', 'install'], cwd=build_dir, ...)
```

**Lines 430-441 - Vite build commands:**

```jac
# Current
command = ['npx', 'vite', 'build', '--config', str(config_rel)];
command = ['npm', 'run', 'build'];

# Replace with
command = ['bun', 'x', 'vite', 'build', '--config', str(config_rel)];
command = ['bun', 'run', 'build'];
```

**Lines 651-654 - Dev server:**

```jac
# Current
result = subprocess.run(['npm', 'install', '--progress'], cwd=build_dir, ...)

# Replace with
result = subprocess.run(['bun', 'install'], cwd=build_dir, ...)
```

**Lines 681-683 - Start dev server:**

```jac
# Current
process = subprocess.Popen(['npx', 'vite', '--config', str(config_rel), '--port', str(port)], cwd=build_dir)

# Replace with
process = subprocess.Popen(['bun', 'x', 'vite', '--config', str(config_rel), '--port', str(port)], cwd=build_dir)
```

### 2.3 Babel Compilation in `babel_processor.impl.jac`

**The entire compile() method needs replacement.**

Current flow:

1. Copy package.json to .jac/client/
2. Run `npm install`
3. Run `npm run compile` (which runs Babel)
4. Clean up

New flow with Bun:

1. Copy package.json to .jac/client/
2. Run `bun install`
3. Use Vite directly (Bun's native transpilation handles JSX/TSX)
4. Clean up

**Recommendation:** This file can be deleted entirely since Bun+Vite handles transpilation natively.

### 2.4 Desktop Target in `desktop_target.impl.jac`

**Lines 1303-1313 - npm Tauri CLI check:**

```jac
# Current
result = subprocess.run(['npm', 'list', '-g', '@tauri-apps/cli'], ...)

# Replace with - just use cargo tauri (preferred anyway)
# Remove npm check entirely, keep only cargo tauri check
```

**Lines 1374-1392 - npm install Tauri CLI:**

```jac
# Current
result = subprocess.run(['npm', 'install', '-g', '@tauri-apps/cli'], ...)

# Replace with
result = subprocess.run(['bun', 'add', '-g', '@tauri-apps/cli'], ...)
# Or better: just use cargo install tauri-cli
```

**Lines 1850, 2236-2239 - Tauri build/dev commands:**

```jac
# Current
build_cmd = ["npm", "run", "tauri", "build"];
dev_cmd = ["npm", "run", "tauri", "dev"];

# Replace with
build_cmd = ["bun", "run", "tauri", "build"];
dev_cmd = ["bun", "run", "tauri", "dev"];
# Or better: use cargo tauri directly
```

---

## 3. Configuration Files to Update

### 3.1 `@jac-client/jac-client-devDeps/package.json`

Current:

```json
{
  "name": "@jac-client/dev-deps",
  "version": "1.0.0",
  "dependencies": {
    "vite": "^6.4.1",
    "@babel/cli": "^7.28.3",
    "@babel/core": "^7.28.5",
    "@babel/preset-env": "^7.28.5",
    "@babel/preset-react": "^7.28.5",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0"
  }
}
```

After migration:

```json
{
  "name": "@jac-client/dev-deps",
  "version": "2.0.0",
  "dependencies": {
    "vite": "^6.4.1",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0"
  }
}
```

**Reduction: 4 packages removed (all Babel-related)**

### 3.2 `defaults/package_scripts.json`

Current:

```json
{
  "build": "npm run compile && vite build --config .jac/client/configs/vite.config.js",
  "dev": "vite dev --config .jac/client/configs/vite.config.js",
  "preview": "vite preview --config .jac/client/configs/vite.config.js",
  "compile": "babel compiled --out-dir build --extensions \".jsx,.js\" --out-file-extension .js"
}
```

After migration:

```json
{
  "build": "vite build --config .jac/client/configs/vite.config.js",
  "dev": "vite dev --config .jac/client/configs/vite.config.js",
  "preview": "vite preview --config .jac/client/configs/vite.config.js"
}
```

**Reduction: Removed "compile" script and "npm run compile &&" prefix**

---

## 4. Test Infrastructure Changes

### 4.1 `conftest.py`

**Replace npm references:**

```python
# Line 170-176 - Change jac add --npm to work with bun
result = subprocess.run(
    [*jac_cmd, "add", "--npm"],  # This command likely stays the same
    ...
)

# Remove _get_env_with_npm() function entirely
# Remove NVM path detection logic
```

**Cache directory changes:**

```python
# npm_cache_dir fixture → bun_cache_dir
# node_modules handling remains similar (Bun uses node_modules too)
```

### 4.2 `test_helpers.py`

**Replace entire `get_env_with_npm()` function with simpler version:**

```python
def get_env_with_bun() -> dict[str, str]:
    """Get environment dict with bun in PATH."""
    env = os.environ.copy()
    bun_path = shutil.which("bun")
    if bun_path:
        bun_dir = str(Path(bun_path).parent)
        current_path = env.get("PATH", "")
        if bun_dir not in current_path:
            env["PATH"] = f"{bun_dir}:{current_path}"
    return env
```

---

## 5. Documentation Updates Required

### Files to update:

- `README.md` - Change npm references to bun
- `jac_client/docs/advance/package-management.md`
- `jac_client/docs/styling/tailwind.md`
- `jac_client/docs/working-with-ts.md`
- All example README.md files (14+ files)
- `architecture.md`

### Key message changes:

- "npm install" → "bun install"
- "npx vite" → "bun x vite" or just "bunx vite"
- "Node.js and npm required" → "Bun required"
- Installation instructions: Link to https://bun.sh

---

## 6. Summary of Changes by File

| File | Action | Lines Affected |
|------|--------|----------------|
| `babel_processor.jac` | DELETE | ~20 lines |
| `babel_processor.impl.jac` | DELETE | ~90 lines |
| `node_installer.jac` | DELETE | ~30 lines |
| `node_installer.impl.jac` | DELETE | ~240 lines |
| `vite_bundler.impl.jac` | MODIFY | ~80 lines changed |
| `package_installer.impl.jac` | MODIFY | ~30 lines changed |
| `desktop_target.impl.jac` | MODIFY | ~50 lines changed |
| `conftest.py` | MODIFY | ~40 lines changed |
| `test_helpers.py` | MODIFY | ~25 lines changed |
| `jac-client-devDeps/package.json` | MODIFY | 4 deps removed |
| `package_scripts.json` | MODIFY | 2 scripts simplified |

**Total estimated code removal: ~400-500 lines**
**Total code modifications: ~225 lines**

---

## 7. Migration Benefits

### 7.1 Performance Improvements

- **Package installation**: Bun is 10-100x faster than npm
- **Build times**: Native transpilation is faster than Babel
- **Dev server startup**: Faster due to Bun's runtime

### 7.2 Simplified Codebase

- No more Babel configuration
- No more NVM version management
- Fewer dev dependencies (4 fewer packages)
- Simpler package.json scripts

### 7.3 Reduced Complexity

- Single tool (Bun) instead of npm + npx + nvm
- Native TypeScript/JSX support without additional tooling
- Simpler error messages (just "install Bun" vs complex Node.js setup)

---

## 8. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Bun compatibility with some npm packages | Test with all examples; most React packages work |
| Tauri CLI npm dependency | Use `cargo install tauri-cli` instead |
| User adoption (need to install Bun) | Clear error messages with install instructions |
| Lock file differences (bun.lockb) | Add to .gitignore patterns, document change |

---

## 9. Recommended Implementation Order

1. **Phase 1: Core package manager replacement**
   - Replace npm commands in `package_installer.impl.jac`
   - Replace npm commands in `vite_bundler.impl.jac`
   - Update error messages

2. **Phase 2: Remove Babel**
   - Delete `babel_processor.jac` and impl
   - Update package.json scripts
   - Update `@jac-client/jac-client-devDeps/package.json`

3. **Phase 3: Remove Node version management**
   - Delete `node_installer.jac` and impl
   - Simplify test infrastructure

4. **Phase 4: Desktop target updates**
   - Update Tauri CLI installation
   - Update build/dev commands

5. **Phase 5: Documentation and examples**
   - Update all README files
   - Update docs

6. **Phase 6: Testing**
   - Run all examples with Bun
   - Update and run test suite
