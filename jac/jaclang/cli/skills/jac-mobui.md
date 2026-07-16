---
name: jac-mobui
description: Building a cross-platform mobile + web app with MobUI - `client_kind = "mobui"`, the `@jac/mobui` primitives (View/Text/Pressable/TextInput/ScrollView), the no-HTML rule (E1105), RN props/events, StyleSheet styling, cross-platform icons, and the `jac start --client react-native` build. Load when the user wants a mobile / iOS / Android / React Native app, or when editing any `client_kind = "mobui"` project. This is the React Native target - for the Capacitor webview wrapper of a web bundle see `jac-mobile-app`.
---

MobUI is Jac's cross-platform UI model: **one source compiles to both native React Native (Expo/Metro) and web (react-native-web)**. It is turned on by `client_kind = "mobui"` in `jac.toml`, which flips on a compiler guard that bans HTML. You author entirely in `@jac/mobui` primitives - **no `<div>`, no `className`, no CSS**.

This is a different target from `jac-mobile-app` (Capacitor), which wraps the *web* bundle in a webview and keeps HTML. MobUI is real React Native components. The in-repo examples are `jac/examples/mobui/` (`hello`, `littlex`); the worked product-scale reference app is `jachammer` (a mobile clone of jacBuilder) in the jacBuilder repo under `mobile/` - copy its patterns.

A MobUI app is still a normal Jac full-stack app: backend `node`/`walker:pub` in the server section, and a `cl { }` client block (or `.cl.jac` files) built from primitives. All of `jac-walker-patterns`, `jac-sv-endpoints`, `jac-sv-persistence` apply to the backend unchanged.

## The one hard rule: NO raw HTML (E1105)

In a `mobui` project, any lowercase HTML tag that doesn't resolve to an in-scope component is **`E1105`, which blocks codegen**. Use the primitive instead:

| HTML (FORBIDDEN) | MobUI primitive |
|---|---|
| `<div>`, `<section>`, `<header>`, `<nav>`, `<li>` | `<View>` |
| `<span>`, `<p>`, `<h1>`–`<h6>`, `<label>` | `<Text>` - **all text must sit inside a `<Text>`** |
| `<button>`, `<a>` | `<Pressable>` |
| `<input>`, `<textarea>` | `<TextInput>` |
| `<img>` | `<Image>` |
| `<ul>`, `<ol>`, scroll containers | `<ScrollView>` |

Your own uppercase components (`<TweetCard/>`) are always allowed.

⚠ **File-layout trap.** The guard is enforced on `main.jac`'s `cl {}` block and on `.native.cl.jac` files, but NOT on plain `.cl.jac` files (they may target the web boundary). So a `<div>` in `Card.cl.jac` compiles clean yet breaks on native. **Never rely on the compiler to catch HTML** - use `@jac/mobui` primitives everywhere, or author the app in `main.jac`'s `cl {}` like jachammer.

## Component shape

Same rules as any `.cl.jac` (see `jac-cl-components`): a `def:pub` returning `JsxElement`, `has` fields are reactive state (assign directly, no `setX`), `async can with entry` is the mount effect, the top-level entry is `def:pub app -> JsxElement`. **This is Jac, not JS** - Python-style ternary `{X if c else Y}`, comprehensions not `.map()`, `str()` around ints in text.

```jac
cl {
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

        return <ScrollView style={styles.screen} contentContainerStyle={styles.body}>
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
        </ScrollView>;
    }
}
```

## RN props & events (NOT DOM)

| Web `.cl.jac` | MobUI |
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
**Backend** - call walkers as usual: `result = root spawn create(name=txt); fresh = result.reports[0];` or `sv import` + `await fn(arg)` (positional). Auth: `import from "@jac/runtime" { jacLogin, jacSignup, jacLogout }` (backed by `expo-secure-store` on native).

## Styling - React Native `StyleSheet` only

No CSS, no Tailwind, no `className`. `style={...}` objects of camelCase RN properties built with `StyleSheet.create`. Merge/override with an array - later wins: `style={[styles.pill, {backgroundColor: col}]}`.

**Token-theme pattern (idiomatic).** Put design tokens in `theme.cl.jac` as globals and a `buildStyles` factory so the whole app re-skins from one place (jachammer/littlex pattern):

```
# theme.cl.jac
cl {
    import from "@jac/mobui" { StyleSheet }
    glob:pub DARK = {bg: "#0b0d12", surface: "#12151c", text: "#e6e9ef",
                     muted: "#8a93a6", accent: "#7c5cff", danger: "#f4544e"};
    glob:pub LIGHT = {bg: "#f5f6fb", surface: "#ffffff", ...};   # SAME keys, other values
    glob:pub S = {xs: 4, sm: 8, md: 12, lg: 16, xl: 20};        # spacing
    glob:pub R = {sm: 8, md: 12, lg: 16, pill: 999};            # radii
    glob:pub F = {sm: 14, md: 16, lg: 20, xl: 26};              # font sizes

    def:pub buildStyles(C: dict) -> dict {
        return StyleSheet.create({
            screen: {flex: 1, backgroundColor: C.bg},
            card:   {backgroundColor: C.surface, borderRadius: R.md, padding: S.lg, gap: S.sm},
            title:  {color: C.text, fontSize: F.xl, fontWeight: "bold"}
        });
    }
}
```

Runtime theme switch: prebuild both sheets once (`glob STYLES_DARK = buildStyles(DARK);`), pick one per render off a `has` field.

Supported props are the RN flexbox subset: `flex`, `flexDirection`, `alignItems`, `justifyContent`, `gap`, `padding*`, `margin*`, `backgroundColor`, `borderRadius`, `borderWidth`, `borderColor`, `width`/`height`/`maxWidth`, `position:"absolute"` + `top`/`left`/…, and (on `<Text>` only) `color`, `fontSize`, `fontWeight`, `lineHeight`, `textAlign`.

Styling gotchas:

- ⚠ **Default `flexDirection` is `column`** - set `"row"` explicitly for rows.
- ⚠ **Text style goes on `<Text>`, layout on `<View>`** - `color`/`fontSize` on a `<View>` is ignored.
- **No CSS shorthand strings** - `padding: "8px 16px"` and `"1px solid #ccc"` are invalid; use `paddingVertical`/`paddingHorizontal` and `borderWidth`+`borderColor`. Colors are plain strings (hex/`rgba()`).

## Project setup & build

```toml
# jac.toml
[project]
name = "my-mobile-app"
version = "1.0.0"
client_kind = "mobui"          # THE switch - without it it's a web app and HTML is allowed
entry-point = "main.jac"

[plugins.client]

[dependencies.npm]
react = "^18.2.0"
react-dom = "^18.2.0"
react-native-web = "^0.19.13"      # REQUIRED - the web target aliases @jac/mobui to this
lucide-react = "^0.469.0"          # icons (web) - optional
lucide-react-native = "^0.469.0"   # icons (native) - optional
react-native-svg = "^15.13.0"      # peer dep of lucide-react-native
```

`client_kind` accepts only `"web"` (default) or `"mobui"`. Run `jac install` after editing `jac.toml`.

```bash
jac start main.jac --dev                          # WEB preview (react-native-web via Vite) - iframe-able
jac setup react-native                            # one-time Expo scaffold → .jac/mobile-rn/
jac start main.jac --client react-native --dev    # NATIVE (Metro; press a/i, or Expo Go QR)
jac build                                          # web bundle
jac build --client react-native --platform android # APK (gradle or EAS)
jac build --client react-native --platform ios     # .app / .ipa (xcodebuild on macOS, or EAS)
```

**Iterate on `jac start main.jac --dev`** - the web (react-native-web) target renders `View`→`div`, `Text`→`span` and hot-reloads in a browser. Native needs Metro + a device/simulator and can't render in a plain iframe. Optional native config lives under `[plugins.client.react_native]` (`project_dir`, `default_platform`, `android_builder`/`ios_builder` = `gradle`/`xcodebuild`/`eas`, `eas_profile`, OTA `eas_update*`).

## Cross-platform icons & native modules

`@jac/mobui` ships no icons. Use Lucide split into two files with the **identical** `Icon` API - the compiler picks `.native.cl.jac` for the react-native target, else `.cl.jac`:

```
# icon.cl.jac  (WEB)                          # icon.native.cl.jac  (NATIVE)
cl {                                          cl {
    import from "lucide-react" { Rocket }         import from "lucide-react-native" { Rocket }
    glob LUCIDE = {rocket: Rocket};               glob LUCIDE = {rocket: Rocket};
    def:pub Icon(name: str, size: int,            def:pub Icon(name: str, size: int,
                 color: str) -> JsxElement {                    color: str) -> JsxElement {
        Glyph = LUCIDE[name];                         Glyph = LUCIDE[name];
        return <Glyph size={size} color={color}/>;    return <Glyph size={size} color={color}/>;
    }                                             }
}                                             }
```

Use `<Icon name="rocket" size={20} color={C.accent}/>` - one call, both platforms; keep the two `LUCIDE` key sets in sync. Any platform-exclusive native module follows the same `.cl.jac` + `.native.cl.jac` pair pattern - last resort; prefer primitives that absorb the divergence.

## Keyboard & platform helpers

Import from `@jac/mobui`: `Platform`, `Keyboard`, `KeyboardAvoidingView`, `useWindowDimensions`, `Animated`, `Easing`, `createAnimatedValue`.

```jac
import from "@jac/mobui" { KeyboardAvoidingView, Keyboard, Platform }
def kbBehavior() -> str { return "padding" if Platform.OS == "ios" else "height"; }
# wrap input screens:  <KeyboardAvoidingView behavior={kbBehavior()}> ... </KeyboardAvoidingView>
# dismiss on submit:   Keyboard.dismiss();
```

## Scaffolding checklist (new MobUI app)

1. `jac.toml` with `client_kind = "mobui"` + the npm deps above.
2. `main.jac` - backend `node`/`walker:pub`, then a `cl {}` with `def:pub app -> JsxElement`; author the whole UI here in primitives (file-layout trap above).
3. `theme.cl.jac` - token globals + `buildStyles`.
4. `icon.cl.jac` + `icon.native.cl.jac` if icons are needed.
5. `jac install`, then `jac start main.jac --dev` and validate.

## See also

- `jac-cl-components` - shared `.cl.jac` rules (state, effects, JSX-in-Jac, pitfalls) that all still apply
- `jac-mobile-app` - the **Capacitor** target (webview wrapper of a web bundle; keeps HTML) - different from MobUI
- `jac-fullstack-patterns`, `jac-walker-patterns`, `jac-sv-endpoints` - the backend the UI calls
- `jac-project-kinds` - target comparison
- Examples: `jac/examples/mobui/` (`hello`, `littlex`); product-scale reference: `jachammer` in the jacBuilder repo (`mobile/`)
