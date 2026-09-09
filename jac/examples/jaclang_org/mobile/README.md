# JacYac mobile

The React Native face of JacYac. `main.jac` renders
`core/jacyac/native/JacYacMobile.jac`, which is also embedded on the website.
Both it and the web renderer consume `core/jacyac/state.jac` and
`core/jacyac/session.jac`; graph operations and error handling are shared.

The UI uses `@jac/mobui` primitives, native styles, the shared JacYac SVG,
real uploaded avatars (initials when absent), and the same light/dark
palette as web. Theme changes propagate to the live phone embed. Native
fonts load through Expo Font from the configured Jac backend. The native
bio editor uses the shared profile update operation, including clearing a bio.

```bash
jac install
jac run web
jac setup mobile
jac run --dev mobile
jac run --dev --platform web mobile
jac build mobile --platform android
jac build mobile --platform ios
jac test mobile
```

The web preview uses React Native Web; it is not a native-device test.
`core/jacyac/native/icon.native.jac` selects native icons while the default
variant uses browser icons. `core/brand/font.native.jac` loads the same
Geist font asset used by web. See the workspace README for shared ownership,
brand generation, and validation commands.

Ninja Scores is available from the Scores tab, including before sign-in.
Repository search, sorting, GitHub repository selection, and project mutations
use the same shared state as the web app. Submissions appear publicly under
the submitting JacYac profile.

GitHub sign-in opens the system browser through Expo WebBrowser. Jac Scale
completes the provider callback, and the initiating device redeems the result
using its private, expiring polling secret. No GitHub client secret is bundled
into the app, and no custom URL scheme is required. Configure the backend's
GitHub OAuth credentials and callback as described in the workspace README.
A physical device needs a reachable HTTPS backend rather than the development
loopback URL. Browser previews use the web PKCE flow instead.
