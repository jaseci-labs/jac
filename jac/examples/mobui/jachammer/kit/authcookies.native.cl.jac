"""Clear the SSO WebView's cookies on logout so the next social sign-in starts
fresh (shows the account picker instead of silently re-using the session).

Talks to the underlying native cookie module directly through `NativeModules`
rather than the @react-native-cookies/cookies wrapper. That wrapper runs an
`invariant()` at *import* time which hard-crashes Expo Go (where the native
side is absent) before any try/except can catch it. Reading
`NativeModules.RNCookieManager*` never throws: it's a real module in a
dev/standalone build and simply `undefined` in Expo Go — so this auto-degrades
to a safe no-op with **no build-time comment/uncomment toggling**.
"""

cl {
    import from "@jac/mobui" { Platform }
    import from 'react-native' { NativeModules }

    async def:pub clearAuthCookies {
        try {
            mgr = (
                NativeModules.RNCookieManagerIOS
                if Platform.OS == "ios"
                else NativeModules.RNCookieManagerAndroid
            );
            if not mgr {
                # Expo Go (or any build without the native cookie module).
                console.log("[jh] cookie clear skipped (native module absent)");
                return;
            }
            # useWebKit=True clears WKWebView's store (what react-native-webview
            # uses on iOS); the False pass covers the legacy/Android store.
            await mgr.clearAll(True);
            await mgr.clearAll(False);
            console.log("[jh] auth cookies cleared");
        } except Exception as e {
            console.log("[jh] cookie clear unavailable", e);
        }
    }
}
