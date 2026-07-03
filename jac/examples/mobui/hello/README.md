# mobui-hello

Starter for **mobUI** -- Jac's cross-platform UI model
(`[project] client_kind = "mobui"`). One source tree compiles to **both** the
web (via `react-native-web`) and **React Native** (Android/iOS).

```bash
jac start main.jac                       # web    -> View=<div>, Text=<span> (react-native-web)
jac start main.jac --client react-native # native -> real RN components (Expo + Metro)
```

## The `@jac/mobui` vocabulary

The app is authored entirely in `@jac/mobui` primitives -- there is no `<div>`,
`<span>`, `<button>`, `<input>`, or `<img>` anywhere in `main.jac`.

| `@jac/mobui` primitive | Replaces HTML          | Used here for       |
|---------------------|------------------------|---------------------|
| `View`              | `div`/`section`/`main` | layout & cards      |
| `Text`              | `span`/`p`/`h1…h6`     | any string          |
| `Pressable`         | `button`/`a`           | tap targets         |
| `TextInput`         | `input`/`textarea`     | controlled input    |
| `Image`             | `img`                  | the avatar          |
| `ScrollView`        | `ul`/`ol`/scroll area  | scroll container    |
| `StyleSheet`        | CSS / `className`      | `style={{…}}` objects only |

Styling is React Native's model only: `style={{…}}` objects over a flexbox
subset. No CSS files, no `className`, by construction.

## Compile-time enforcement (E1105)

In a mobUI project, raw HTML host tags are **compile errors** with a fix-it
pointing at the `@jac/mobui` primitive to use instead. Try adding a `<div>` to
`main.jac` and run `jac check`:

```
error[E1105]: JSX tag '<div>' is not in scope in a mobUI project;
use View instead
```

The guard resolves every tag name in the enclosing scope:

- **Uppercase components** (`<Card>`, `<Image>`) are always allowed.
- **Lowercase components that resolve to an in-scope symbol are allowed.**
- Only **unresolved lowercase names** (`div`, `span`, …) are treated as HTML
  host elements and rejected.
- `.cl.jac` web-boundary files are exempt -- raw HTML stays valid where the
  code can only run in a browser.

See the
[jac-client Reference → React Native Target](https://docs.jaseci.org/reference/plugins/jac-client/#react-native-target-beta)
for the full component vocabulary and the HTML → `@jac/mobui` mapping. For a
full-stack example (graph persistence, walker RPC, platform-split icon
modules) see [`examples/mobui/littlex`](../littlex).
