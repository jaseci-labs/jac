# jachammer - a pocket Jac studio

The **mobile-first** counterpart to jacBuilder, built on
[`@jac/mobui`](../../../jaclang/runtimelib/client/client_mobui.cl.jac). One Jac
codebase compiles to a real **React Native** app (Expo/Metro) *and* the web
(`react-native-web`) - no `<div>`, no `className`, no platform fork.

Where [`hello`](../hello) is the primitive tour and [`littlex`](../littlex) is a
small self-contained full-stack app, **jachammer** is the *product* showcase: a
complete, multi-screen mobile client for the **hosted jacBuilder backend**. There
is **no local backend in this directory** - jachammer authenticates with the
runtime's `jacLogin`/SSO and drives jacBuilder's live walkers over
`root spawn …()`, exactly as the jacBuilder web IDE does. It even speaks
jacBuilder's own **WebSocket build protocol** so the AI assistant streams a real
app into a live preview.

```bash
# native - the primary target (real RN components on a device/simulator)
jac start main.jac --client react-native --dev

# web preview - View=<div>, Text=<span> via react-native-web
jac start main.jac --dev
```

> You need a **jacBuilder account** to use the app - sign in with a username /
> password or **Continue with Google / GitHub** on the Auth screen. The backend
> URL is `JB_API` in `lib/constants.cl.jac`
> (`https://jac-builder-dev.jaseci.org` by default); the store pins it onto
> `globalThis.__JAC_API_BASE_URL__` on mount so every `root spawn`, the auth
> calls, the SSO flow and the build WebSocket all hit the hosted gateway. The AI
> build assistant runs **server-side on jacBuilder**, so there is no local
> provider key or `byllm` setup here.

---

## Architecture

A single **React Context store** holds all state and every backend action; screens
and components are pure consumers. This mirrors jacBuilder's own separation but is
shaped for React Native (sibling screens under one provider rather than routed
pages).

```
main.jac                      # <StudioProvider><Root/></StudioProvider> + screen switch + overlays
hooks/useStudio.cl.jac        # the Context provider - all has-state, actions, the value dict, useStudio()
services/api.cl.jac           # one async def:pub per jacBuilder walker (thin RPC layer)
lib/
  constants.cl.jac            # JB_API, suggestion chips, plan catalogue
  mappers.cl.jac              # pure report→view mappers (jbProj / jbComm / jbMsg / prettyModel …)
  authcookies.cl.jac(.native) # clear the SSO WebView cookies on logout (native module; no-op in Expo Go)
ui/
  theme.cl.jac                # design tokens + light/dark StyleSheets
  icon.cl.jac(.native)        # Lucide icons (lucide-react on web, lucide-react-native on native)
screens/                      # Home, Projects, Community, Activity, Profile, AppShell, Auth, Detail, Sheets, Billing
components/                   # one small presentational component per file (cards, chips, pills, rows, composer, …)
```

Platform splits use the `*.native.cl.jac` convention - e.g. `PreviewFrame` and
`SsoModal` have a native (WebView) implementation and a web fallback; the compiler
picks the right one per target.

State is plain `has` fields (→ `useState`); a functional-update `markBusy(key,
val)` drives per-action loading flags without clobbering concurrent updates.
Walker `reports` are plain dicts, mapped through `lib/mappers` into the thin local
mirror (`projects`, `communityItems`, `messages`, `curFiles`, `templates`,
`models`, `monitor`, `billing`) that the store refreshes after each mutation.

---

## Backend integration

Every piece of real data comes from a jacBuilder walker (or a jac-cloud auth
endpoint). One `async def:pub` per walker lives in `services/api.cl.jac`.

| Area | Backend call | Notes |
|------|--------------|-------|
| Sign in / up / out | `jacLogin` · `jacSignup` · `jacLogout` | from `@jac/runtime` |
| **Social sign-in** | `GET /sso/{google,github}/login` → intercept `?token=` | in-app WebView; see [Social sign-in](#social-sign-in) |
| Account bootstrap | `me` | creates the server-side `UserProfile`, returns billing tier + balance |
| Display name | `GET /user/me` | resolves the real name for SSO users (JWT carries only `user_id`) |
| Projects | `project_ops(action=list/create/rename/delete)` | cards map from `_project_to_dict` |
| **Session claim** | `project_ops(action="claim_session")` | binds the project to this client's sandbox - required before preview/files work |
| **AI build turn** | `ai_chat(start)` → WS `ide_preview_stream` → `ai_chat(persist_done)` | see [The build pipeline](#the-build-pipeline) |
| Model switch | `model_switch(project_id, model)` | picker list = the tier's real `models_allowed` |
| Files | `ide_file_ops(action=list/read)` | reads the live project staging dir |
| **Live preview** | `preview_control(action=start/status)` + WebView | renders the real Vite sandbox URL |
| Deploy | `deploy_ops(action=deploy/destroy/status, deploy_mode=…)` | sandbox (7-day) or permanent; polls `status` for the live URL |
| Monitor | `deploy_monitoring(action=overview/metrics/logs)` | pods, restarts, request/error series, pod logs |
| Templates | `template_ops(action="list")` | drives the New-project picker |
| Community | `community_ops` · `community_submit` | browse / clone / publish |
| Billing display | `me → billing` | tier, remaining/top-up balance, project quota |

---

## The build pipeline

This is the heart of jachammer and a faithful port of jacBuilder's real transport

- **not** a poll-and-hope shim. When you send a prompt:

1. **`ai_chat(action="start")`** kicks off the turn server-side and returns a
   `run_id` + `checkpoint_ref`. (The *first* start on a fresh project can `504` at
   the gateway while the JacCoder session cold-starts - jachammer treats a `504`
   as "turn already running" and streams it rather than retrying blindly.)
2. **WebSocket** `wss://…/api/builder_sv/ws/ide_preview_stream` - jachammer opens
   the socket with a fresh `connection_id` and polls the `ai_events` action every
   ~500 ms, draining the Redis-backed event stream. (The HTTP `poll` action can't
   be used - the walker has no `connection_id` param, so it always drains empty.)
3. Events flow in (`file_promoted`, `agent_activity`, … then **`agent_done`**);
   jachammer accumulates promoted files and reads the final reply.
4. **`ai_chat(action="persist_done")`** finalizes the turn - this is what writes
   the assistant message and clears the server-side processing flag (without it,
   `load_history` never shows the reply).
5. The chat reloads, the view switches to **Preview**, and the WebView reloads so
   Vite's freshly-built app appears.

The agent writes code straight into the running sandbox, so the preview updates
live. A steady "Generating your app…" state shows on both the chat and preview
tabs for the whole turn; genuine failures surface as a `⚠️` message in chat.

---

## Social sign-in

"Continue with Google / GitHub" runs jac cloud's SSO inside an **in-app WebView**
(`components/SsoModal.native.cl.jac`):

- jac cloud only honours a **loopback** `client_callback`, so a mobile deep link
  is rejected - instead the token lands on the web callback and jachammer
  **intercepts the `…?token=<JWT>` redirect** in the WebView before it renders,
  matching the token only at a real query boundary and requiring a proper JWT
  shape (so Google's own `id_token=` is never mistaken for it).
- The JWT carries only `user_id`; the real name comes from **`/user/me`**
  (`profile.sso.<provider>.display_name`), exactly like jacBuilder's web callback.
- **GitHub** renders fine in a WebView. **Google** blocks embedded WebViews by
  default, so the WebView presents a desktop user-agent to get through (a
  workaround suitable for internal/demo use; production should use the
  system-browser popup - which requires a small jac-cloud change to accept the
  app's return scheme, or an on-device loopback server).
- **Logout** calls `clearAuthCookies()` so the next sign-in shows the account
  picker. This uses `@react-native-cookies/cookies` - a native module that is a
  **safe no-op in Expo Go** and activates in a **dev/standalone build**.

---

## What's real vs. local

- **Real backend:** auth (password + SSO), account/profile, project CRUD, session
  claim, the full AI build turn (WebSocket stream + persist), model switch, file
  tree & viewer, live preview (WebView of the real sandbox), deploy /
  status / stop / restart, `deploy_monitoring`, community clone/publish, and the
  billing summary.
- **Web checkout:** the billing **Upgrade / change plan** button opens jacBuilder's
  web checkout - mobile can't do in-app plan purchase (jacBuilder itself defers to
  Stripe on the web).
- **Client-side only:** the **Activity** feed and **notifications** badge are a
  local record of the operations *you* performed this session (jacBuilder exposes
  no mobile activity walker), and the **theme** toggle.
- **Static UI copy (same as jacBuilder):** the Home suggestion chips and the plan
  catalogue cards - jacBuilder hardcodes these on the client too. Your *own* tier +
  balance is live via `me`; only the public catalogue is static.

---

## The mobUI vocabulary

Authored entirely in `@jac/mobui` primitives - no raw HTML anywhere:

| primitive | used here for |
|-----------|---------------|
| `View` / `Text` / `Pressable` | every layout box, all copy, every tappable |
| `TextInput` | auth fields, search, new-project name, chat composer |
| `ScrollView` | each scrollable screen |
| `Animated` | the splash logo entrance |
| `Keyboard` / `Platform` / `KeyboardAvoidingView` | lifting inputs above the keyboard |
| `ActivityIndicator` | button + walker-call spinners |
| `StyleSheet` | the token-based design system in `ui/theme.cl.jac` |

Native-only surfaces reach past mobUI directly: `react-native-webview` for the
preview and SSO, `@react-native-cookies/cookies` for logout.

---

## Keyboard handling

Input-bearing surfaces lift above the keyboard: the chat composer tracks the
keyboard height via a manual `Keyboard` listener (a plain `KeyboardAvoidingView`
doesn't reliably lift a flex-bottom composer on iOS), and auth / new-project sheets
use `KeyboardAvoidingView` with a platform-appropriate `behavior`. Submitting
dismisses the keyboard via `Keyboard.dismiss()`.

---

## Theme

A "forge" charcoal (`#0b0d12`) with an electric-violet primary (`#7c5cff`) for
navigation/brand and a warm amber (`#ff9d3c`) for build/deploy actions. Status
reads at a glance: green = running, amber = building, muted = stopped, red =
failed. Full **dark / light / system** support - every colour/spacing/radius lives
in the token globals at the top of `ui/theme.cl.jac`; edit those to re-skin the
whole app.

---

## Running on a device

- **Expo Go** - fastest inner loop; everything works except logout cookie-clearing
  (SSO still signs you in; the account picker after logout needs the dev build).

  ```bash
  cd .jac/mobile-rn && npx expo start -c
  ```

- **Dev build** - needed for the native cookie module (account picker on logout):

  ```bash
  cd .jac/mobile-rn
  eas build --profile development --platform android   # or ios
  # then run the bundler and connect the dev app to it
  npx expo start
  ```
