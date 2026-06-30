# mobui-tags

Showcase for the **mobUI Tag System** - Jac's v2 cross-platform UI model
(`[project] client_kind = "mobui"`). One source tree compiles to **both** the web
(via `react-native-web`) and **React Native** (Android/iOS).

## What it demonstrates

This app is authored entirely in the `@jac/ui` component vocabulary - there is
no `<div>`, `<span>`, `<button>`, `<input>`, or `<img>` anywhere in `main.jac`.

### 1. The `@jac/ui` vocabulary

| `@jac/ui` primitive  | Replaces HTML | Used here for        |
|----------------------|---------------|----------------------|
| `View`               | `div`/`section`/`main` | layout & cards |
| `Text`               | `span`/`p`/`h1…h6`     | any string     |
| `Pressable`          | `button`/`a`           | tap targets     |
| `TextInput`          | `input`/`textarea`     | controlled input |
| `Image`              | `img`                  | the avatar       |
| `ScrollView`         | `ul`/`ol`/scroll area  | scroll container |
| `StyleSheet`         | CSS / `className`      | `style={{…}}` objects only |

Styling is React Native's model only: `style={{…}}` objects over a flexbox
subset. No CSS files, no `className`, by construction.

### 2. Compile-time enforcement (E1105)

In a mobUI project, raw HTML host tags are **compile errors** with a fix-it
pointing at the `@jac/ui` primitive to use instead. Try adding a `<div>` to
`main.jac` and run `jac check` - you'll get:

```
error[E1105]: JSX tag '<div>' is not in scope in a mobUI project;
use View instead
```

This replaces the old regex-lint / runtime red-border fallbacks. The compiler
sees the full AST, so the diagnostic points at the exact source span.

### 3. Scope-based tag resolution

The guard resolves every tag name in the enclosing scope:

- **Uppercase components** (`<Card>`, `<Image>`) are always allowed.
- **Lowercase components that resolve to an in-scope symbol are allowed.**
  See the local `counter` component in `main.jac`: `<counter …/>` compiles
  fine because `counter` is defined in the same module.
- Only **unresolved lowercase names** (`div`, `span`, …) are treated as HTML
  host elements and rejected.

## Run it

```bash
jac check main.jac                         # tag system: expect 0 E1105
jac build main.jac                         # web bundle (react-native-web)
jac build main.jac --client react-native   # Android/iOS bundle (Metro)
```

## Status

`jac check` passes cleanly (0 E1105). The `@jac/ui` vocabulary and the E1105
guard are the tag system under test here; see the
[jac-client Reference -> React Native Target](https://docs.jaseci.org/reference/plugins/jac-client/#react-native-target-beta)
for the full component vocabulary, the HTML -> `@jac/ui` mapping, and the
ownership rationale behind owning a thin vocabulary layer over raw React
Native / `react-native-web`.
