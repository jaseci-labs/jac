# Jac-Client Roadmap

## 🎯 High level roadmap

1. Relative path resolving - @Jason - Done
2. Bundler Plugin POC - Done
3. React style DX - Done
4. Dev mode with HRM
5. Jac install - universal pakcage manager for jac-client
5. Migrate SLAM / Large project to document and improve the DX
6. OSP in FE
    - [ ] migrate to browser router

## 1. Current Stack (React Style)
- **State & Lifecycle**: React Hooks (useState, useEffect, etc.)
- **Routing**: Declarative JSX components
- **Backend**: `jacSpawn` for walker communication
- **Auth**: Built-in helpers (jacLogin, jacSignup, jacLogout)
- **Bundler**: Vite + Babel
- **CLI**: `jac create_jac_app`, `jac serve`

---

## ✅ Completed Features

### Core Runtime
- ✅ JSX Factory (`__jacJsx`) - React.createElement integration
- ✅ Fragment support (`<></>`)
- ✅ Spread props
- ✅ React 19 createRoot rendering
- ✅ Full React hooks support (useState, useEffect, useReducer, useContext, useMemo, useCallback, useRef)
- ✅ Event handling (onClick, onChange, onSubmit, onKeyPress, etc.)

### Routing (@jac-client/utils)
- ✅ Declarative components: `<Router>`, `<Routes>`, `<Route>`, `<Link>`, `<Navigate>`
- ✅ Routing hooks: `useNavigate()`, `useLocation()`, `useRouter()`
- ✅ Programmatic navigation: `navigate(path)`
- ✅ Hash-based routing (#/path)
- ✅ Browser history integration
- ✅ Basename support
- ⏳ URL params, query strings - Planned
- ⏳ Nested routes - Planned

### Backend Communication (@jac-client/utils)
- ✅ `jacSpawn(walker, node_id, params)` - Walker calling
- ✅ Automatic JWT token injection
- ✅ Async/await support
- ⏳ Retry logic - Planned
- ⏳ Timeouts - Planned
- ⏳ Request cancellation - Planned

### Authentication (@jac-client/utils)
- ✅ `jacLogin(username, password)`
- ✅ `jacSignup(username, password)`
- ✅ `jacLogout()`
- ✅ `jacIsLoggedIn()`
- ✅ Automatic token management
- ⏳ Token refresh - ?
- ⏳ Session expiration handling - ?

### Build & Bundling
- ✅ Vite bundler integration
- ✅ Babel compilation
- ✅ Tree-shaking and optimization (vite)
- ✅ External library support (npm packages)
- ✅ `@jac-client/utils` alias resolution
- ✅ Production builds with hashing

### CLI
- ✅ `jac create_jac_app <name>` - Project scaffolding
- ✅ `jac serve <file.jac>` - Dev server
- ✅ Automatic bundling
- ⏳ HMR (Hot Module Replacement) - Planned
- ⏳ `jac install` - Universal package manager - Planned

### Examples
- ✅ basic/ - Counter with React hooks
- ✅ with-router/ - Multi-page navigation
- ✅ basic-full-stack/ - Todo app with backend
- ✅ little-x/ - Social media app (complex)

### Legacy APIs (Deprecated but Supported)
- ⚠️ `createSignal()` → Use `useState`
- ⚠️ `createState()` → Use `useState`
- ⚠️ `onMount()` → Use `useEffect`
- ⚠️ `initRouter()` → Use `<Router>` components

## 📋 Testing Coverage Needed

### High Priority
- [ ] Component rendering (nested, props, conditional, lists)
- [ ] React hooks (useState, useEffect with cleanup, useReducer)
- [ ] Routing (navigation, protected routes, 404 handling)
- [ ] Server communication (jacSpawn with error handling)
- [ ] Authentication flow (login, signup, logout, protected pages)
- [ ] Build & bundle (production builds, tree-shaking, hashing)

### Medium Priority
- [ ] External libraries (Antd, lodash, other npm packages)
- [ ] Event handling (all event types, prevention, bubbling)
- [ ] Cross-browser testing (Chrome, Firefox, Safari, Edge)
- [ ] Form handling and validation

### Low Priority
- [ ] Performance testing
- [ ] Bundle size optimization
- [ ] Source maps verification


## 📦 Planned Features ( TO be validated)

### High Priority
- [ ] **URL params & query strings** - Routing enhancement
- [ ] **Request retry logic & timeouts** - Server communication reliability
- [ ] **Token refresh & session handling** - Auth improvements
- [ ] **Error boundaries** - Better error handling

### Medium Priority
- [ ] **Nested routes** - Advanced routing patterns
- [ ] **OSP in FE** - Object-Spatial Programming on frontend
- [ ] **Global state management** - Shared state across components
- [ ] **Form handling utilities** - High-level form state management
- [ ] **Loading states utilities** - Async data management helpers
- [ ] **Context/scope helpers** - Share data without prop drilling

### Low Priority
- [ ] **Component memoization** - Auto-optimization

## 📚 Documentation

See `jac_client/docs/` for detailed guides:
- README.md - Getting started tutorial
- routing.md - Routing guide
- lifecycle-hooks.md - React hooks guide
- imports.md - Import system
- advanced-state.md - Complex state patterns

---

