# Jac-Client: npm → Bun Migration Progress Tracker

**Started:** 2025-01-24
**Target Completion:** TBD
**Status:** 🟡 In Progress

---

## Overview

| Phase | Description | Status | Progress |
|-------|-------------|--------|----------|
| 1 | Core Package Manager Replacement | ✅ Complete | 5/5 |
| 2 | Remove Babel | ✅ Complete | 4/4 |
| 3 | Remove Node Version Management | ✅ Complete | 3/3 |
| 4 | Desktop Target Updates | ✅ Complete | 4/4 |
| 5 | Test Infrastructure | ⬜ Not Started | 0/4 |
| 6 | Documentation & Examples | ⬜ Not Started | 0/5 |
| 7 | Final Testing & Validation | ⬜ Not Started | 0/4 |

**Legend:** ⬜ Not Started | 🟡 In Progress | ✅ Complete | ❌ Blocked

---

## Phase 1: Core Package Manager Replacement

Replace all npm/npx commands with bun equivalents.

### Tasks

- [x] **1.1** Update `package_installer.impl.jac`
  - [x] Replace `['npm', 'install', '--progress']` → `['bun', 'install']`
  - [x] Update error message: "npm command not found" → "bun command not found"
  - [x] Update user-facing messages: "npm packages" → "packages"

- [x] **1.2** Update `vite_bundler.impl.jac` - Package Installation
  - [x] Line ~406: Replace `['npm', 'install', '--progress']` → `['bun', 'install']`
  - [x] Line ~654: Replace `['npm', 'install', '--progress']` → `['bun', 'install']`
  - [x] Update all "npm install" user messages

- [x] **1.3** Update `vite_bundler.impl.jac` - Build Commands
  - [x] Line ~430: Replace `['npx', 'vite', 'build', ...]` → `['bun', 'x', 'vite', 'build', ...]`
  - [x] Line ~441: Replace `['npm', 'run', 'build']` → `['bun', 'run', 'build']`

- [x] **1.4** Update `vite_bundler.impl.jac` - Dev Server
  - [x] Line ~682: Replace `['npx', 'vite', '--config', ...]` → `['bun', 'x', 'vite', '--config', ...]`

- [x] **1.5** Update error messages throughout
  - [x] Change "Ensure Node.js and npm are installed" → "Ensure Bun is installed: https://bun.sh"

### Notes

```
Files modified:
- [x] jac_client/plugin/src/impl/package_installer.impl.jac
- [x] jac_client/plugin/src/impl/vite_bundler.impl.jac
```

---

## Phase 2: Remove Babel

Remove Babel dependency entirely - Bun handles JSX/TSX transpilation natively.

### Tasks

- [x] **2.1** Delete Babel processor files
  - [x] Delete `jac_client/plugin/src/babel_processor.jac`
  - [x] Delete `jac_client/plugin/src/impl/babel_processor.impl.jac`

- [x] **2.2** Update `vite_bundler.impl.jac`
  - [x] Remove Babel config from `create_package_json()` (lines ~55-57)
  - [x] Remove `'compile'` script from scripts dict (line ~51)
  - [x] Remove `'npm run compile &&'` from build script (line ~48)
  - [x] Remove `'babel': babel_config` from package_data (line ~67)

- [x] **2.3** Update `@jac-client/jac-client-devDeps/package.json`
  - [x] Remove `"@babel/cli": "^7.28.3"`
  - [x] Remove `"@babel/core": "^7.28.5"`
  - [x] Remove `"@babel/preset-env": "^7.28.5"`
  - [x] Remove `"@babel/preset-react": "^7.28.5"`

- [x] **2.4** Update `defaults/package_scripts.json`
  - [x] Remove `"compile"` script
  - [x] Update `"build"` to remove `npm run compile &&` prefix

### Notes

```
Files deleted:
- [x] jac_client/plugin/src/babel_processor.jac
- [x] jac_client/plugin/src/impl/babel_processor.impl.jac

Files modified:
- [x] jac_client/plugin/src/impl/vite_bundler.impl.jac
- [x] jac_client/plugin/src/compiler.jac (removed BabelProcessor import)
- [x] jac_client/plugin/src/impl/compiler.impl.jac (removed Babel usage, use compiled/ directly)
- [x] jac_client/plugin/src/__init__.jac (removed BabelProcessor export)
- [x] @jac-client/jac-client-devDeps/package.json
- [x] jac_client/plugin/defaults/package_scripts.json
```

---

## Phase 3: Remove Node Version Management

Remove NVM integration - Bun is self-contained and doesn't need Node.js.

### Tasks

- [x] **3.1** Delete Node installer files
  - [x] Delete `jac_client/plugin/utils/node_installer.jac`
  - [x] Delete `jac_client/plugin/utils/impl/node_installer.impl.jac`

- [x] **3.2** Remove Node installer imports/references
  - [x] Search for and remove any imports of `NodeInstaller`
  - [x] Remove any calls to `ensure_node_installed()`

- [x] **3.3** Update CLI if needed
  - [x] Check `cli.jac` for Node.js checks - no changes needed (CLI has no Node.js checks)
  - [x] Replace with Bun availability check if needed - done in plugin_config.jac

### Notes

```
Files deleted:
- [x] jac_client/plugin/utils/node_installer.jac
- [x] jac_client/plugin/utils/impl/node_installer.impl.jac

Files modified:
- [x] jac_client/plugin/plugin_config.jac (replaced NodeInstaller with shutil.which('bun'))

Files checked (no changes needed):
- [x] jac_client/plugin/cli.jac (no Node.js checks found)
```

---

## Phase 4: Desktop Target Updates

Update Tauri integration to use Bun instead of npm.

### Tasks

- [x] **4.1** Update Tauri CLI installation check
  - [x] Replace `npm list -g @tauri-apps/cli` → `bun pm ls -g` check
  - [x] Keep cargo-based check as primary method

- [x] **4.2** Update Tauri CLI installation
  - [x] Replace `['npm', 'install', '-g', '@tauri-apps/cli']` → `['bun', 'add', '-g', '@tauri-apps/cli']`
  - [x] Update all npm availability checks to bun

- [x] **4.3** Update Tauri build commands
  - [x] Changed default to `["cargo", "tauri", "build"]`
  - [x] Fallback to `["bun", "run", "tauri", "build"]` if package.json has tauri scripts

- [x] **4.4** Update Tauri dev commands
  - [x] Changed default to `["cargo", "tauri", "dev"]`
  - [x] Fallback to `["bun", "run", "tauri", "dev"]` if package.json has tauri scripts
  - [x] Updated error messages to reference bun instead of npm

### Notes

```
Files modified:
- [x] jac_client/plugin/src/targets/impl/desktop_target.impl.jac
```

---

## Phase 5: Test Infrastructure

Update test fixtures and helpers for Bun.

### Tasks

- [ ] **5.1** Update `conftest.py`
  - [ ] Remove `_get_env_with_npm()` function or simplify for Bun
  - [ ] Update `npm_cache_dir` fixture → consider renaming to `bun_cache_dir`
  - [ ] Remove NVM path detection logic
  - [ ] Update subprocess calls from npm to bun

- [ ] **5.2** Update `test_helpers.py`
  - [ ] Replace `get_env_with_npm()` → `get_env_with_bun()`
  - [ ] Remove NVM-specific path detection (~20 lines)

- [ ] **5.3** Update test fixtures
  - [ ] `fixtures/with-ts/package.json` - update scripts if needed
  - [ ] Update any npm-specific test assertions

- [ ] **5.4** Run test suite
  - [ ] Ensure all tests pass with Bun
  - [ ] Fix any Bun-specific issues

### Notes

```
Files modified:
- [ ] jac_client/tests/conftest.py
- [ ] jac_client/tests/test_helpers.py
- [ ] jac_client/tests/fixtures/with-ts/package.json
- [ ] jac_client/tests/test_it.py (if needed)
- [ ] jac_client/tests/test_cli.py (if needed)
- [ ] jac_client/tests/test_e2e.py (if needed)
```

---

## Phase 6: Documentation & Examples

Update all documentation and example projects.

### Tasks

- [ ] **6.1** Update main documentation
  - [ ] `README.md` - Change npm → bun references
  - [ ] `architecture.md` - Update tooling description
  - [ ] `import-system.md` - Update if npm mentioned

- [ ] **6.2** Update docs folder
  - [ ] `docs/README.md`
  - [ ] `docs/advance/package-management.md`
  - [ ] `docs/advance/configuration-overview.md`
  - [ ] `docs/advance/custom-config.md`
  - [ ] `docs/styling/tailwind.md`
  - [ ] `docs/working-with-ts.md`
  - [ ] `docs/imports.md`
  - [ ] All other docs with npm references

- [ ] **6.3** Update example READMEs (14+ files)
  - [ ] `examples/all-in-one/README.md`
  - [ ] `examples/basic/README.md`
  - [ ] `examples/basic-auth/README.md`
  - [ ] `examples/basic-full-stack/README.md`
  - [ ] `examples/with-router/README.md`
  - [ ] `examples/ts-support/README.md`
  - [ ] `examples/css-styling/*/README.md` (6 files)
  - [ ] `examples/asset-serving/*/README.md` (3 files)
  - [ ] `examples/nested-folders/*/README.md` (2 files)

- [ ] **6.4** Update .gitignore patterns
  - [ ] Add `bun.lockb` if not already ignored
  - [ ] Keep `node_modules/` (Bun uses it too)

- [ ] **6.5** Update `BUN_MIGRATION_ANALYSIS.md`
  - [ ] Mark as historical/completed
  - [ ] Add final notes

### Notes

```
Documentation files to update: ~25+ files
```

---

## Phase 7: Final Testing & Validation

Comprehensive testing before merge.

### Tasks

- [ ] **7.1** Test all examples with Bun
  - [ ] `examples/basic` - builds and runs
  - [ ] `examples/basic-full-stack` - builds and runs
  - [ ] `examples/with-router` - builds and runs
  - [ ] `examples/ts-support` - TypeScript works
  - [ ] `examples/css-styling/*` - all 6 styling examples
  - [ ] `examples/asset-serving/*` - all 3 asset examples
  - [ ] `examples/all-in-one` - comprehensive test

- [ ] **7.2** Test desktop target
  - [ ] Desktop setup works
  - [ ] Desktop build works
  - [ ] Desktop dev works

- [ ] **7.3** Run full test suite
  - [ ] `pytest jac_client/tests/` passes
  - [ ] No regressions

- [ ] **7.4** Manual smoke test
  - [ ] Fresh project: `jac init` + `jac build` works
  - [ ] `jac add <package>` works
  - [ ] `jac start` (dev mode) works
  - [ ] HMR works in dev mode

---

## Blockers & Issues

Track any blockers or issues encountered during migration.

| Issue | Description | Status | Resolution |
|-------|-------------|--------|------------|
| - | - | - | - |

---

## Changelog

| Date | Phase | Changes |
|------|-------|---------|
| 2025-01-24 | - | Created migration analysis and progress tracker |
| 2025-01-24 | 1 | Completed Phase 1: Replaced npm/npx with bun in package_installer.impl.jac and vite_bundler.impl.jac |
| 2025-01-24 | 2 | Completed Phase 2: Removed Babel entirely - deleted babel_processor files, removed Babel config, 4 Babel deps removed |
| 2025-01-24 | 3 | Completed Phase 3: Removed Node version management - deleted node_installer files, replaced with shutil.which('bun') check |
| 2025-01-24 | 4 | Completed Phase 4: Desktop target updates - replaced npm with bun for Tauri CLI check/install, build and dev commands default to cargo |

---

## Final Checklist

Before marking migration complete:

- [ ] All phases completed
- [ ] All tests passing
- [ ] All examples working
- [ ] Documentation updated
- [ ] No npm/npx references remain in code
- [ ] Clean PR ready for review
