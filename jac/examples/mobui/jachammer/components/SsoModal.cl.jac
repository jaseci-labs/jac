"""Web fallback for social sign-in: jac cloud's SSO is a full-page redirect on
the web (it lands back on the configured web callback, which stores the token),
so we just navigate there. The WebView-based native flow lives in
SsoModal.native.cl.jac.
"""

cl {
    import from "@jac/mobui" { View }
    import from react { useEffect }
    import from ..hooks.useStudio { useStudio }

    def:pub SsoModal -> JsxElement {
        s = useStudio();
        url = s["ssoUrl"];
        useEffect(lambda {
            if url != "" {
                globalThis.location.href = url;
            }
        }, [url]);
        return <View/>;
    }
}
