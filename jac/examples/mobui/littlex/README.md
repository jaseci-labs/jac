# LittleX, cross-platform

A small social feed -- post, persist, like -- in **one `main.jac` file** that runs on
**web and native from the same source**. It's the mobUI counterpart to
[`examples/littleX`](../../littleX): same idea (a graph of `Tweet` nodes with walkers
as the API), but the UI is built entirely from portable
[`@jac/mobui`](../../../jaclang/runtimelib/client/client_mobui.cl.jac)
primitives instead of raw `<div>`/`<button>`/antd -- so it isn't locked to the browser.

## What it demonstrates

- **Full stack in one file.** The top of `main.jac` is the backend: a `Tweet` node
  persisted on the graph and `walker:pub` endpoints (`load_feed`, `create_tweet`,
  `like_tweet`). The `cl { }` block is the cross-platform UI.
- **Client calls the backend directly** -- `root spawn create_tweet(...)` /
  `tid spawn like_tweet()` compile to walker RPCs; you read `result.reports`.
- **Every primitive in the contract**: `View`, `Text`, `Pressable`, `TextInput`,
  `Image`, `ScrollView`, `StyleSheet.create`, plus an `Animated` mount transition.
- **Real Lucide icons, cross-platform** via a platform-split module: `icon.cl.jac`
  uses `lucide-react` on web (plain DOM SVG -- no `react-native-svg`, so the web
  bundle stays clean), and `icon.native.cl.jac` uses `lucide-react-native` on
  native (Metro bundles its SVG fine). Same `<Icon name=.../>` API on both.
- **No raw HTML.** There is no `<div>` anywhere -- the bundler aliases `@jac/mobui` to the
  compiled primitive module and (on web only) rewrites `react-native -> react-native-web`.

## Run it

```bash
# web -- View=<div>, Text=<span> via react-native-web
jac start main.jac --dev

# native -- real React Native components on a device/simulator
jac start main.jac --dev --client react-native
```

Then post something. It's stored as a `Tweet` node on the shared root graph and
survives restarts. Because the walkers are `:pub`, everyone shares one timeline and
no login is required -- flip a walker to `:priv` to give each authenticated user their
own isolated graph.

## Theme

OLED-black (`#000000`) with an X-style sky-blue accent (`#1d9bf0`) and a pink like
(`#f91880`). All colors/spacing/radii live in the `C`/`S`/`R`/`F` token globals at the
top of the `cl { }` block -- change those to re-skin the whole app.
