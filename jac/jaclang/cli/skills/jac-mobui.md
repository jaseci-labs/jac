---
name: jac-mobui
description: Write mobile components using native views and mobUI. Use for mobile rendering, navigation, styling, or E1105 host-tag diagnostics.
---

MobUI is Jac's cross-platform UI model: **one source compiles to both native React Native (Expo/Metro) and web (react-native-web)**. Every `kind = "mobile"` app is a MobUI app: the kind on the app's `[apps.<name>]` table in `jac.toml` (or `[project] kind` in a single-app project) turns on a compiler guard that bans HTML in that app's modules (and nowhere else - a web app in the same workspace keeps its HTML). You author entirely in `@jac/mobui` primitives - **no `<div>`, no `className`, no CSS**.

MobUI is real React Native components, not a web page in a webview. The in-repo example is the flagship workspace's mobile app, `jac/examples/jaclang_org/mobile/` (`jac create <name> --awesome` scaffolds the whole workspace) - a React Native client for the same social graph the site serves, with typed theme tokens, `.native.jac` icon variants, and `BridgeError` handling; the product-scale reference is `jachammer` (a mobile clone of jacBuilder) in the jacBuilder repo under `apps/mobile/` - copy their patterns.

A MobUI app is a **client app** of its workspace: it has no server of its own. Its screens import walkers / `def:pub` functions from shared `core/` code that a serving app (the `web-app`, or a declared `service` entry) serves, and every `root spawn` / call bridges to that provider - in the flagship, `core/social_graph.jac` is `[apps.social_graph]`'s entry file and `mobile/` is one of its clients. All of `jac-walker-patterns`, `jac-sv-endpoints`, `jac-sv-persistence` apply to that backend unchanged; `jac-sv-microservices` covers the bridge and the `BridgeError` family.

## The one hard rule: NO raw HTML (E1105)

In a `mobile` app, any lowercase HTML tag that doesn't resolve to an in-scope component is **`E1105`, which blocks codegen**. Use the primitive instead:

| HTML (FORBIDDEN) | MobUI primitive |
|---|---|
| `<div>`, `<section>`, `<header>`, `<nav>`, `<li>` | `<View>` |
| `<span>`, `<p>`, `<h1>`–`<h6>`, `<label>` | `<Text>` - **all text must sit inside a `<Text>`** |
| `<button>`, `<a>` | `<Pressable>` |
| `<input>`, `<textarea>` | `<TextInput>` |
| `<img>` | `<Image>` |
| `<ul>`, `<ol>`, scroll containers | `<ScrollView>` - use `<FlatList>` / `<SectionList>` once the list can grow past a screenful |
| `<dialog>` | `<Modal>` |
| `<input type="checkbox">` | `<Switch>` |

Your own uppercase components (`<TweetCard/>`) are always allowed.

⚠ **File-layout trap.** The guard covers the modules the mobUI app claims (everything under its `path`) - but plain `.jac` component files that can only run in a browser are exempt (`.native.jac` files never are). So a `<div>` in a web-boundary `Card.jac` can compile clean yet break on native. **Never rely on the compiler to catch HTML** - use `@jac/mobui` primitives everywhere.

## Component shape

Same rules as any client component (see `jac-cl-components`): a `def:pub` returning `JsxElement`, `has` fields are reactive state (assign directly, no `setX`), `async can with entry` is the mount effect, the top-level entry is `def:pub app -> JsxElement`. **This is Jac, not JS** - Python-style ternary `{X if c else Y}`, comprehensions not `.map()`, `str()` around ints in text.

```jac
import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, StyleSheet }

glob styles = StyleSheet.create({
    screen: {flex: 1, backgroundColor: "#0b0d12"},
    body:   {padding: 16, gap: 12},
    button: {padding: 12, borderRadius: 12, backgroundColor: "#7c5cff", alignItems: "center"},
    label:  {color: "#ffffff", fontSize: 16, fontWeight: "bold"}
});

def:pub app -> JsxElement {
    has count: int = 0, name: str = "";

    async can with entry {
        count = 0;                                    # mount effect
    }

    <ScrollView style={styles.screen} contentContainerStyle={styles.body}>
        <Text>Hello, {name}</Text>
        <TextInput
            value={name}
            placeholder="Type your name"
            placeholderTextColor="#8a93a6"
            onChangeText={lambda (t: str) { name = t; }}
        />
        <Pressable style={styles.button} onPress={lambda { count = count + 1; }}>
            <Text style={styles.label}>Clicks: {str(count)}</Text>
        </Pressable>
    </ScrollView>
}
```

## RN props & events (NOT DOM)

| Web `.jac` | MobUI |
|---|---|
| `onClick={h}` | `onPress={h}` |
| `onChange` → `e.target.value` | `onChangeText={lambda (t: str) { field = t; }}` (string directly) |
| `<img src="x">` | `<Image source={{uri: "https://..."}} style={...}/>` |
| `<input placeholder=..>` | `<TextInput placeholder=.. placeholderTextColor=.. secureTextEntry={True} multiline={True}/>` |
| `className="..."` | `style={styles.x}` |
| ScrollView inner padding | `contentContainerStyle={styles.body}` (separate from `style`) |

Handlers are usually inline `lambda`; close over row data: `onPress={lambda { open(p["id"]); }}`.

**Lists** - comprehension in a JSX slot with a `key`: `{[<Card key={p["id"]} p={p}/> for p in items]}`.
**Conditionals** - Jac ternary; empty branch is `<View/>`: `{(<Progress/>) if busy else <View/>}`.
**Components** declare props as typed params: `def Card(p: dict) -> JsxElement {...}`, called `<Card p={p}/>`.
**Backend** - call walkers as usual: `result = root spawn create(name=txt); fresh = result.reports[0];` or import the server function + `await fn(arg)` (positional). Both bridge to the provider app; wrap them in `try { ... } except BridgeError as e { ... }` (`import from "@jac/runtime" { BridgeError, BridgeUnavailable, BridgeTimeout, BridgeRejected }`) and show a retry banner rather than a blank screen - the flagship's `components/BridgeBanner.jac` is the pattern. Auth: `import from "@jac/runtime" { jacLogin, jacSignup, jacLogout }` (backed by `expo-secure-store` on native).

## Styling - React Native `StyleSheet` only

No CSS, no Tailwind, no `className`. `style={...}` objects of camelCase RN properties built with `StyleSheet.create`. Merge/override with an array - later wins: `style={[styles.pill, {backgroundColor: col}]}`.

**Token-theme pattern (idiomatic).** Put design tokens in `theme.jac` as **`obj`s with typed fields**, export one instance of each, and build one `StyleSheet` from them - so `C.accent` is a typed attribute read the checker verifies, never a dict looked up by attribute (the flagship `mobile/theme.jac` pattern):

```
# theme.jac
import from "@jac/mobui" { StyleSheet }

obj Colors {
    has bg: str = "#0b0d12", surface: str = "#12151c", text: str = "#e6e9ef",
        muted: str = "#8a93a6", accent: str = "#7c5cff", danger: str = "#f4544e";
}
obj Spacing { has xs: int = 4, sm: int = 8, md: int = 12, lg: int = 16, xl: int = 20; }
obj Radii   { has sm: int = 8, md: int = 12, lg: int = 16, pill: int = 999; }
obj Fonts   { has sm: int = 14, md: int = 16, lg: int = 20, xl: int = 26; }

glob:pub C = Colors(), S = Spacing(), R = Radii(), F = Fonts();

glob:pub styles = StyleSheet.create({
    screen: {flex: 1, backgroundColor: C.bg},
    card:   {backgroundColor: C.surface, borderRadius: R.md, padding: S.lg, gap: S.sm},
    title:  {color: C.text, fontSize: F.xl, fontWeight: "bold"}
});
```

Re-skin the whole app by editing the field defaults; for a runtime light/dark switch keep two `Colors` instances and a `buildStyles(c: Colors) -> dict` factory, prebuild both sheets once, pick one per render off a `has` field. ⚠ A `dict` accessed by attribute (`C.bg` on a `glob C = {...}`) is `E1030` - use an `obj`.

Supported props are the RN flexbox subset: `flex`, `flexDirection`, `alignItems`, `justifyContent`, `gap`, `padding*`, `margin*`, `backgroundColor`, `borderRadius`, `borderWidth`, `borderColor`, `width`/`height`/`maxWidth`, `position:"absolute"` + `top`/`left`/…, and (on `<Text>` only) `color`, `fontSize`, `fontWeight`, `lineHeight`, `textAlign`.

Styling gotchas:

- ⚠ **Default `flexDirection` is `column`** - set `"row"` explicitly for rows.
- ⚠ **Text style goes on `<Text>`, layout on `<View>`** - `color`/`fontSize` on a `<View>` is ignored.
- **No CSS shorthand strings** - `padding: "8px 16px"` and `"1px solid #ccc"` are invalid; use `paddingVertical`/`paddingHorizontal` and `borderWidth`+`borderColor`. Colors are plain strings (hex/`rgba()`).

## Project setup & build

`jac create --app mobile --kind mobile` (inside a workspace) or `jac create my-mobile-app --kind mobile` (a single-app project) writes this:

```toml
# jac.toml
[project]
name = "my-mobile-app"
version = "1.0.0"
default-app = "mobile"

[apps.mobile]
kind = "mobile"                # THE switch: native views via Expo/Metro, @jac/mobui only (HTML is E1105)
entry-point = "mobile.main" # relative to the project root
platform = "android"           # optional default for `jac run mobile` / `jac build mobile`

[dependencies.npm]
react = "^19.2.0"
react-dom = "^19.2.0"
react-native-web = "^0.19.13"      # REQUIRED - the web target aliases @jac/mobui to this
lucide-react = "^0.469.0"          # icons (web) - optional
lucide-react-native = "^0.469.0"   # icons (native) - optional
react-native-svg = "^15.13.0"      # peer dep of lucide-react-native
```

Mobile-only npm deps can go in the app's overlay, `[apps.mobile.dependencies.npm]`; packages only the Expo project needs go under `[dependencies.npm.native]`. Run `jac install` after editing `jac.toml`.

```bash
jac run --dev --platform web mobile      # WEB preview (react-native-web via Vite) - iframe-able
jac setup mobile                         # one-time Expo scaffold → .jac/mobile-rn/
jac run --dev mobile                     # NATIVE (Metro; press a/i, or Expo Go QR)
jac build mobile --platform android      # APK (gradle or EAS)
jac build mobile --platform ios          # .app / .ipa (xcodebuild on macOS, or EAS)
jac build mobile --platform web          # the browser bundle (dist/mobile/ under `jac build --all --platform web`)
jac test mobile                          # the app's pure-Jac helpers
jac run web                              # in another terminal: the server the screens bridge to
```

(Single-app project: drop the app name.) **Iterate on `jac run --dev --platform web mobile`** - the web platform (react-native-web) renders `View`→`div`, `Text`→`span` and hot-reloads in a browser. Native needs Metro + a device/simulator and can't render in a plain iframe. Optional native config lives under `[client.react_native]` (`project_dir`, `default_platform`, `android_builder`/`ios_builder` = `gradle`/`xcodebuild`/`eas`, `eas_profile`, OTA `eas_update*`) - see `jac-mobile-app`.

## Cross-platform icons & native modules

`@jac/mobui` ships no icons. Use Lucide split into two files with the **identical** `Icon` API - the compiler picks `.native.jac` for the app's native platforms (android / ios) and `.jac` for its web platform (a stamped decision, never the filename alone), and **checks the two agree**: same names, kinds, parameters and annotations, or `E5105` on the variant:

```
# icon.jac  (WEB)                                 # icon.native.jac  (NATIVE)
import from "lucide-react" { Rocket }             import from "lucide-react-native" { Rocket }
glob LUCIDE = {rocket: Rocket};                   glob LUCIDE = {rocket: Rocket};
def:pub Icon(name: str, size: int,                def:pub Icon(name: str, size: int,
             color: str) -> JsxElement {                       color: str) -> JsxElement {
    Glyph = LUCIDE[name];                             Glyph = LUCIDE[name];
    return <Glyph size={size} color={color}/>;        return <Glyph size={size} color={color}/>;
}                                                 }
```

Use `<Icon name="rocket" size={20} color={C.accent}/>` - one call, both platforms; keep the two `LUCIDE` key sets in sync (E5105 catches signature drift, not data drift). Any platform-exclusive native module follows the same `.jac` + `.native.jac` pair pattern - last resort; prefer primitives that absorb the divergence.

## Keyboard & platform helpers

Import from `@jac/mobui`: `Platform`, `Keyboard`, `KeyboardAvoidingView`, `useWindowDimensions`, `Dimensions`, `StatusBar`, `Animated`, `Easing`, `createAnimatedValue`, `Alert`, `Linking`.

`Platform.select` is available too - reach for a `.native.jac` file pair only when the two platforms need *different imports*, not to branch on a value:

```jac
import from "@jac/mobui" { Platform }
glob pad = Platform.select({"ios": 20, "android": 12, "default": 16});
```

```jac
import from "@jac/mobui" { KeyboardAvoidingView, Keyboard, Platform }
def kbBehavior() -> str { return "padding" if Platform.OS == "ios" else "height"; }
# wrap input screens:  <KeyboardAvoidingView behavior={kbBehavior()}> ... </KeyboardAvoidingView>
# dismiss on submit:   Keyboard.dismiss();
```

## Scaffolding checklist (new MobUI app)

1. `jac create --app mobile --kind mobile` (or `--kind mobile` on a new project): an `[apps.mobile]` table with `kind = "mobile"` + the npm deps above.
2. `main.jac` - `def:pub app -> JsxElement` (auth gate, state, screen switch); the backend it bridges to lives in shared `core/` and is compiled in a serving app context - NOT inside the mobile app.
3. `theme.jac` - token `obj`s + one `StyleSheet`.
4. `screens/` + `components/` in primitives only; `icon.jac` + `icon.native.jac` if icons are needed.
5. `jac install`, then `jac run --dev --platform web mobile` and validate; `jac check` gates the whole workspace (E1105, E5105, E2039).

## See also

- `jac-cl-components` - shared client-component rules (state, effects, JSX-in-Jac, pitfalls) that all still apply
- `jac-mobile-app` - the toolchain side: Expo scaffold, `[client.react_native]` builders, EAS Build / Update, devices
- `jac-fullstack-patterns`, `jac-walker-patterns`, `jac-sv-endpoints` - the backend the UI calls
- `jac-project-kinds` - target comparison
- `jac-sv-microservices` - the bridge the screens call through, the `BridgeError` family, app contexts for shared `core/`
- Example: the flagship workspace's `jac/examples/jaclang_org/mobile/` (`jac create <name> --awesome`); product-scale reference: `jachammer` in the jacBuilder repo (`apps/mobile/`)
