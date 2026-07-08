# mobUI examples

One source tree, two platforms: these apps are written in the portable
[`@jac/mobui`](../../jaclang/runtimelib/client/client_mobui.cl.jac) vocabulary
(`client_kind = "mobui"` in `jac.toml`) and compile to both the web (via
`react-native-web`) and React Native (via Expo/Metro).

| Example | What it shows |
|---------|---------------|
| [`hello/`](hello) | The starter: every `@jac/mobui` primitive once, the styling model, and the E1105 compile-time guard. Start here. |
| [`littlex/`](littlex) | The full-stack showcase: graph persistence + walker RPC from a native client, `.native.cl.jac` platform-split modules (web vs native icon backends), and a token-based theme. |
| [`jachammer/`](jachammer) | The product showcase: a multi-screen mobile app (splash, auth, tabbed shell, project detail with a live deploy rollout, bottom-sheet modal) — jacBuilder's mobile-first counterpart, built entirely from the primitive vocabulary. |

Run either from its own directory:

```bash
jac start main.jac --dev                          # web
jac start main.jac --client react-native --dev    # native (Expo)
```
