"""Web fallback for clearAuthCookies — no native cookie store to clear here
(the native WebView flow lives in authcookies.native.cl.jac)."""

cl {
    async def:pub clearAuthCookies {
        ;
    }
}
