# Jac-Client: npm → Bun Migration Progress Tracker

**Started:** 2025-01-24
**Target Completion:** TBD
**Status:** 🟡 In Progress

---

## Overview

| Phase | Description | Status | Progress |
|-------|-------------|--------|----------|
| 1 | Core Package Manager Replacement | ✅ Complete | 5/5 |
| 2 | Remove Babel | ⬜ Not Started | 0/4 |
| 3 | Remove Node Version Management | ⬜ Not Started | 0/3 |
| 4 | Desktop Target Updates | ⬜ Not Started | 0/4 |
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

- [ ] **2.1** Delete Babel processor files
  - [ ] Delete `jac_client/plugin/src/babel_processor.jac`
  - [ ] Delete `jac_client/plugin/src/impl/babel_processor.impl.jac`

- [ ] **2.2** Update `vite_bundler.impl.jac`
  - [ ] Remove Babel config from `create_package_json()` (lines ~55-57)
  - [ ] Remove `'compile'` script from scripts dict (line ~51)
  - [ ] Remove `'npm run compile &&'` from build script (line ~48)
  - [ ] Remove `'babel': babel_config` from package_data (line ~67)

- [ ] **2.3** Update `@jac-client/jac-client-devDeps/package.json`
  - [ ] Remove `"@babel/cli": "^7.28.3"`
  - [ ] Remove `"@babel/core": "^7.28.5"`
  - [ ] Remove `"@babel/preset-env": "^7.28.5"`
  - [ ] Remove `"@babel/preset-react": "^7.28.5"`

- [ ] **2.4** Update `defaults/package_scripts.json`
  - [ ] Remove `"compile"` script
  - [ ] Update `"build"` to remove `npm run compile &&` prefix

### Notes

```
Files deleted:
- [ ] jac_client/plugin/src/babel_processor.jac
- [ ] jac_client/plugin/src/impl/babel_processor.impl.jac

Files modified:
- [ ] jac_client/plugin/src/impl/vite_bundler.impl.jac
- [ ] @jac-client/jac-client-devDeps/package.json
- [ ] jac_client/plugin/defaults/package_scripts.json
```

---

## Phase 3: Remove Node Version Management

Remove NVM integration - Bun is self-contained and doesn't need Node.js.

### Tasks

- [ ] **3.1** Delete Node installer files
  - [ ] Delete `jac_client/plugin/utils/node_installer.jac`
  - [ ] Delete `jac_client/plugin/utils/impl/node_installer.impl.jac`

- [ ] **3.2** Remove Node installer imports/references
  - [ ] Search for and remove any imports of `NodeInstaller`
  - [ ] Remove any calls to `ensure_node_installed()`

- [ ] **3.3** Update CLI if needed
  - [ ] Check `cli.jac` for Node.js checks
  - [ ] Replace with Bun availability check if needed

### Notes

```
Files deleted:
- [ ] jac_client/plugin/utils/node_installer.jac
- [ ] jac_client/plugin/utils/impl/node_installer.impl.jac

Files to check for references:
- [ ] jac_client/plugin/cli.jac
- [ ] jac_client/plugin/plugin_config.jac
```

---

## Phase 4: Desktop Target Updates

Update Tauri integration to use Bun instead of npm.

### Tasks

- [ ] **4.1** Update Tauri CLI installation check
  - [ ] Line ~1303-1313: Remove npm-based Tauri CLI check
  - [ ] Keep cargo-based check as primary method

- [ ] **4.2** Update Tauri CLI installation
  - [ ] Line ~1374-1392: Replace `['npm', 'install', '-g', '@tauri-apps/cli']` → `['bun', 'add', '-g', '@tauri-apps/cli']`
  - [ ] Or better: recommend `cargo install tauri-cli` only

- [ ] **4.3** Update Tauri build commands
  - [ ] Line ~1850: Replace `["npm", "run", "tauri", "build"]` → `["bun", "run", "tauri", "build"]`
  - [ ] Consider using `["cargo", "tauri", "build"]` as default

- [ ] **4.4** Update Tauri dev commands
  - [ ] Line ~2236-2239: Replace `["npm", "run", "tauri", "dev"]` → `["bun", "run", "tauri", "dev"]`
  - [ ] Consider using `["cargo", "tauri", "dev"]` as default

### Notes

```
Files modified:
- [ ] jac_client/plugin/src/targets/impl/desktop_target.impl.jac
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

---

## Final Checklist

Before marking migration complete:

- [ ] All phases completed
- [ ] All tests passing
- [ ] All examples working
- [ ] Documentation updated
- [ ] No npm/npx references remain in code
- [ ] Clean PR ready for review
